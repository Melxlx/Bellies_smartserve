import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum DeviceLocationFailure { denied, permanentlyDenied, disabled, timeout, other }

class DeviceLocationException implements Exception {
  final DeviceLocationFailure failure;
  final String message;
  const DeviceLocationException(this.failure, this.message);

  @override
  String toString() => message;
}

/// Acquires one foreground position only after an explicit customer action.
class DeviceLocationService {
  Future<LatLng> currentPosition() async {
    try {
      if (!kIsWeb) {
        if (!await Geolocator.isLocationServiceEnabled().timeout(
          const Duration(seconds: 10),
        )) {
          throw const DeviceLocationException(
            DeviceLocationFailure.disabled,
            'Location services are off. Turn them on, retry, or choose a point on the map.',
          );
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          throw const DeviceLocationException(
            DeviceLocationFailure.permanentlyDenied,
            'Location permission is blocked. Enable it in app settings, or choose a point on the map.',
          );
        }
        if (permission == LocationPermission.denied) {
          throw const DeviceLocationException(
            DeviceLocationFailure.denied,
            'Location permission was denied. Retry to allow it, or choose a point on the map.',
          );
        }
      }
      // On web, getCurrentPosition triggers the browser permission prompt and
      // also works in browsers without the separate Permissions API.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      ).timeout(const Duration(seconds: 25));
      return LatLng(position.latitude, position.longitude);
    } on DeviceLocationException {
      rethrow;
    } on TimeoutException {
      throw const DeviceLocationException(
        DeviceLocationFailure.timeout,
        'Your location took too long to arrive. Move to a clearer area, retry, or choose a point on the map.',
      );
    } on PermissionDeniedException {
      throw DeviceLocationException(
        DeviceLocationFailure.denied,
        kIsWeb
            ? 'Location permission is blocked. Allow location in your browser site settings, then retry. You can also choose a point on the map.'
            : 'Location permission was denied. Retry or choose a point on the map.',
      );
    } on LocationServiceDisabledException {
      throw const DeviceLocationException(
        DeviceLocationFailure.disabled,
        'Location services are off. Turn them on or choose a point on the map.',
      );
    } catch (_) {
      throw DeviceLocationException(
        DeviceLocationFailure.other,
        kIsWeb
            ? 'Location is unavailable. Use HTTPS and allow location in your browser, or choose a point on the map.'
            : 'Your location could not be found. Retry or choose a point on the map.',
      );
    }
  }

  Future<bool> openSettings(DeviceLocationFailure failure) async {
    if (kIsWeb) return false;
    try {
      return failure == DeviceLocationFailure.disabled
          ? await Geolocator.openLocationSettings()
          : await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
