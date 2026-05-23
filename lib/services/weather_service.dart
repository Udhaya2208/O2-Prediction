import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches current weather data from OpenWeatherMap.
class WeatherService {
  // ⚠️ Replace with your own free API key from https://openweathermap.org/api
  static const String _apiKey = '4c29630e0b967ddeb00bb20aeba5c3c4';
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  /// Fetch current weather for [lat], [lon].
  /// Returns a [WeatherData] or `null` on failure.
  static Future<WeatherData?> fetchWeather(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?lat=$lat&lon=$lon&units=metric&appid=$_apiKey',
      );
      final response = await http.get(uri).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WeatherData.fromJson(json);
      }
    } catch (e) {
      // Silently fail — the UI will use a default temperature.
    }
    return null;
  }
}

class WeatherData {
  final double tempCelsius;
  final String description;
  final String icon;
  final String cityName;
  final int humidity;

  WeatherData({
    required this.tempCelsius,
    required this.description,
    required this.icon,
    required this.cityName,
    required this.humidity,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weather = (json['weather'] as List).first as Map<String, dynamic>;

    return WeatherData(
      tempCelsius: (main['temp'] as num).toDouble(),
      description: weather['description'] as String,
      icon: weather['icon'] as String,
      cityName: json['name'] as String? ?? 'Unknown',
      humidity: (main['humidity'] as num).toInt(),
    );
  }
}
