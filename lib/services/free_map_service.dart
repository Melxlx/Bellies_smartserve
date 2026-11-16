import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class FreeMapService {
  // Esri World Street Map High-Res Map Tiles (100% Free, Fast, No API Key, No Watermark)
  final String tileUrlTemplate = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}";
  final String userAgentPackageName = "com.example.bellies_smartserve";

  // OSRM Public Driving Route API
  final String _osrmBaseUrl = "https://router.project-osrm.org/route/v1/driving";

  Future<String?> reverseGeocode(LatLng location) async {
    // 1. Primary: ESRI World Geocoder API (Fastest, zero rate-limits, exact PH barangays & towns)
    try {
      final esriUrl = Uri.parse(
        "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/reverseGeocode?location=${location.longitude},${location.latitude}&f=json"
      );
      final response = await http.get(esriUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['address'] != null) {
          final addr = data['address'];
          final matchAddr = addr['Match_addr']?.toString() ?? '';
          if (matchAddr.isNotEmpty) {
            // Clean up country code or region to keep it short & readable (e.g. "Bukal, Pila, Laguna")
            final parts = matchAddr
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty && s != 'PHL' && s != 'Philippines' && s != 'Calabarzon')
                .toList();
            if (parts.isNotEmpty) {
              return parts.join(', ');
            }
            return matchAddr;
          }
        }
      }
    } catch (e) {
      debugPrint("ESRI Reverse Geocode error: $e");
    }

    // 2. Secondary: OpenStreetMap Nominatim API
    try {
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1"
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'BelliesSmartServe/1.0 (android.app@bellies.com)',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['address'] != null) {
          final addr = data['address'];
          final road = addr['road'] ?? addr['pedestrian'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? addr['village'] ?? addr['hamlet'] ?? '';
          final city = addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['county'] ?? '';
          final state = addr['state'] ?? addr['region'] ?? '';

          final parts = [road, city, state]
              .map((s) => s.toString().trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
        if (data != null && data['display_name'] != null) {
          final String displayName = data['display_name'].toString();
          final split = displayName.split(',');
          if (split.length > 3) {
            return split.sublist(0, 3).join(',').trim();
          }
          return displayName;
        }
      }
    } catch (e) {
      debugPrint("Nominatim Reverse geocoding error: $e");
    }

    return "Pinned Location, Laguna";
  }

  Future<Map<String, dynamic>?> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      final url = Uri.parse(
        "$_osrmBaseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&annotations=true"
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;

          List<LatLng> polyline = geometry.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          return {
            'polyline': polyline,
            'distance': (route['distance'] as num).toDouble() / 1000, // km
            'duration': (route['duration'] as num).toDouble() / 60, // minutes
          };
        }
      }
    } catch (e) {
      debugPrint("OSRM Error: $e");
    }
    return null;
  }
}
