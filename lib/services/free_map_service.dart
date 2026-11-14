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
    try {
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1"
      );
      final response = await http.get(url, headers: {
        'User-Agent': userAgentPackageName,
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['address'] != null) {
          final addr = data['address'];
          final road = addr['road'] ?? addr['pedestrian'] ?? addr['suburb'] ?? '';
          final village = addr['village'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? addr['hamlet'] ?? '';
          final city = addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['county'] ?? '';
          final state = addr['state'] ?? addr['region'] ?? '';

          final parts = [road, village, city, state]
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
      debugPrint("Reverse geocoding error: $e");
    }
    return null;
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
