import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class FreeSearchService {
  final String _baseUrl = "https://nominatim.openstreetmap.org";

  Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    try {
      final url = Uri.parse("$_baseUrl/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=ph");
      final response = await http.get(url, headers: {'User-Agent': 'BelliesSmartServe/1.0'});

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) => {
          'display_name': item['display_name'],
          'lat': double.parse(item['lat']),
          'lon': double.parse(item['lon']),
        }).toList();
      }
    } catch (e) {
      debugPrint("Search Error: $e");
    }
    return [];
  }

  Future<String?> reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse("$_baseUrl/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json");
      final response = await http.get(url, headers: {'User-Agent': 'BelliesSmartServe/1.0'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'];
      }
    } catch (e) {
      debugPrint("Reverse Geocode Error: $e");
    }
    return null;
  }
}
