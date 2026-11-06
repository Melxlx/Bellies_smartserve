import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class FreeMapService {
  // OSM Standard Tile URL
  final String tileUrlTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
  
  // OSRM Public Routing API (Free for non-commercial/low-volume)
  // For production high-volume, self-hosting OSRM is recommended.
  final String _osrmBaseUrl = "https://router.project-osrm.org/route/v1/driving";

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
