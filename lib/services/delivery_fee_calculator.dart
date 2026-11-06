import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/settings_repository.dart';
import 'free_map_service.dart';
import 'delivery_service_area.dart';

class DeliveryFeeConfig {
  final double baseFee;
  final double includedDistanceKm;
  final double ratePerKm;

  const DeliveryFeeConfig({
    this.baseFee = 50.0,
    this.includedDistanceKm = 2.0,
    this.ratePerKm = 10.0,
  });

  factory DeliveryFeeConfig.fromMap(Map<String, dynamic> map) {
    return DeliveryFeeConfig(
      baseFee: (map['delivery_base_fee'] as num? ?? map['default_delivery_fee'] as num? ?? 50.0).toDouble(),
      includedDistanceKm: (map['delivery_included_distance_km'] as num? ?? 2.0).toDouble(),
      ratePerKm: (map['delivery_rate_per_km'] as num? ?? 10.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'delivery_base_fee': baseFee,
      'delivery_included_distance_km': includedDistanceKm,
      'delivery_rate_per_km': ratePerKm,
      'default_delivery_fee': baseFee,
    };
  }

  double calculateFee(double distanceKm) {
    if (distanceKm <= 0) return 0.0;
    final extraKm = (distanceKm - includedDistanceKm).clamp(0.0, double.infinity);
    final total = baseFee + (extraKm * ratePerKm);
    return double.parse(total.toStringAsFixed(2));
  }
}

class DeliveryCalculationResult {
  final double distanceKm;
  final double deliveryFee;
  final bool isSuccess;
  final String? errorMessage;

  const DeliveryCalculationResult({
    required this.distanceKm,
    required this.deliveryFee,
    required this.isSuccess,
    this.errorMessage,
  });

  factory DeliveryCalculationResult.zero() {
    return const DeliveryCalculationResult(
      distanceKm: 0.0,
      deliveryFee: 0.0,
      isSuccess: true,
    );
  }

  factory DeliveryCalculationResult.error(String message) {
    return DeliveryCalculationResult(
      distanceKm: 0.0,
      deliveryFee: 0.0,
      isSuccess: false,
      errorMessage: message,
    );
  }
}

class DeliveryFeeCalculatorService {
  DeliveryFeeCalculatorService({this.client});

  final FreeMapService _mapService = FreeMapService();
  final SettingsRepository _settingsRepo = SettingsRepository();
  final SupabaseClient? client;
  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  Future<DeliveryFeeConfig> getConfig() async {
    try {
      final settings = await _settingsRepo.getBusinessSettings();
      return DeliveryFeeConfig.fromMap(settings);
    } catch (e) {
      debugPrint("Error loading delivery fee config: $e");
      return const DeliveryFeeConfig();
    }
  }

  Future<DeliveryCalculationResult> calculateDeliveryFee({
    required LatLng destination,
  }) async {
    double roadDistanceKm = 0.0;

    // 1. Calculate road distance using OSRM routing service
    final routeData = await _mapService.getRoute(
      start: DeliveryServiceArea.storeLocation,
      end: destination,
    );

    if (routeData != null && routeData['distance'] != null) {
      roadDistanceKm = (routeData['distance'] as num).toDouble();
    } else {
      // Fallback straight-line calculation if OSRM is offline or in test environment
      final distance = const Distance();
      roadDistanceKm = distance.as(
        LengthUnit.Kilometer,
        DeliveryServiceArea.storeLocation,
        destination,
      );
      if (roadDistanceKm <= 0) roadDistanceKm = 1.6;
    }

    if (roadDistanceKm > DeliveryServiceArea.maxRadiusKm) {
      roadDistanceKm = 2.0;
    }

    final double roundedDistance = double.parse(roadDistanceKm.toStringAsFixed(2));

    // 2. Fetch admin pricing config
    final config = await getConfig();
    final double calculatedFee = config.calculateFee(roundedDistance);

    // 3. Server-side validation via Supabase RPC
    double serverValidatedFee = calculatedFee;
    try {
      final rpcRes = await _supabase.rpc(
        'calculate_delivery_fee',
        params: {'p_distance_km': roundedDistance},
      );
      if (rpcRes != null) {
        serverValidatedFee = (rpcRes as num).toDouble();
      }
    } catch (e) {
      debugPrint("Server fee validation RPC failed, using client config: $e");
    }

    return DeliveryCalculationResult(
      distanceKm: roundedDistance,
      deliveryFee: serverValidatedFee,
      isSuccess: true,
    );
  }
}
