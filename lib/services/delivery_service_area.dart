import 'package:latlong2/latlong.dart';

class DeliveryServiceArea {
  /// Store location: Sta. Cruz, Laguna Center
  static const LatLng storeLocation = LatLng(14.2780, 121.4150);

  /// Maximum radius limit in kilometers for Sta. Cruz, Pagsanjan, & Pila
  static const double maxRadiusKm = 8.0;

  /// Strictly allowed municipalities in Laguna
  static const List<String> coveredTowns = [
    'Sta. Cruz',
    'Santa Cruz',
    'Pagsanjan',
    'Pila',
  ];

  /// Calculates distance in kilometers from the store in Sta. Cruz, Laguna
  static double getDistanceKm(LatLng point) {
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, storeLocation, point);
  }

  /// Checks whether a given location is strictly within Sta. Cruz, Pagsanjan, or Pila, Laguna
  static bool isWithinServiceArea(LatLng point, [String? addressText]) {
    final distKm = getDistanceKm(point);

    if (addressText != null && addressText.isNotEmpty) {
      final lower = addressText.toLowerCase();

      // Explicitly reject towns outside Sta. Cruz, Pagsanjan, & Pila
      final excludedTowns = [
        'lumban',
        'magdalena',
        'victoria',
        'calauan',
        'liliw',
        'nagcarlan',
        'majayjay',
        'calamba',
        'los baños',
        'manila',
        'cavite',
        'batangas',
      ];
      for (final excluded in excludedTowns) {
        if (lower.contains(excluded)) {
          return false;
        }
      }

      // Check if address explicitly matches allowed towns
      for (final town in coveredTowns) {
        if (lower.contains(town.toLowerCase())) {
          return distKm <= 10.0; // Reasonable geographic limit for Sta. Cruz, Pagsanjan, Pila
        }
      }
    }

    return distKm <= maxRadiusKm;
  }
}
