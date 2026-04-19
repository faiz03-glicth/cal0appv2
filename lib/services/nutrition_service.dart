import 'dart:convert';
import 'package:http/http.dart' as http;

class NutritionService {
  final String _apiKey = 'YOUR_RAPIDAPI_KEY_HERE'; // Put your key here
  final String _apiHost =
      'calorieninjas.p.rapidapi.com'; // Or the specific host for your Calorie-API

  Future<Map<String, dynamic>> getNutritionData(String query) async {
    final url = Uri.parse(
      'https://calorieninjas.p.rapidapi.com/v1/nutrition?query=$query',
    );

    final response = await http.get(
      url,
      headers: {'X-RapidAPI-Key': _apiKey, 'X-RapidAPI-Host': _apiHost},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch nutrition data: ${response.statusCode}');
    }
  }
}
