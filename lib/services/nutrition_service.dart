import 'dart:convert';
import 'package:http/http.dart' as http;

class NutritionService {
  static const String _apiKey =
      'kal_c906da3cf23128d4f6d0d98aa37e96281d273fbe6ca2fe70b5f22c4c12a83c28'; // Put your key here
  static const String _apiHost = 'https://api.kaloriapi.com/v1';

  static const Map<String, String> _headers = {
    'Authorization': 'Bearer $_apiKey',
    'Content-Type': 'application/json',
  };

  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    try {
      final uri = Uri.parse('$_apiHost/foods/search?q=$query');
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return List<Map<String, dynamic>>.from(
          data['foods'] ?? data['data'] ?? [],
        );
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getFoodById(String id) async {
    try {
      final uri = Uri.parse('$_apiHost/foods/$id');
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
