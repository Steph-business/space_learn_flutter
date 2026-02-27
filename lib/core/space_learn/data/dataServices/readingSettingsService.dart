import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/api_routes.dart';

class ReadingSettings {
  final int readingBgColor;
  final double brightness;
  final double zoomLevel;
  final bool isHorizontal;

  ReadingSettings({
    required this.readingBgColor,
    required this.brightness,
    required this.zoomLevel,
    required this.isHorizontal,
  });

  Map<String, dynamic> toJson() => {
    'reading_bg_color': readingBgColor,
    'brightness': brightness,
    'zoom_level': zoomLevel,
    'is_horizontal': isHorizontal,
  };

  factory ReadingSettings.fromJson(Map<String, dynamic> json) =>
      ReadingSettings(
        readingBgColor: json['reading_bg_color'] as int,
        brightness: (json['brightness'] as num).toDouble(),
        zoomLevel: (json['zoom_level'] as num).toDouble(),
        isHorizontal: json['is_horizontal'] as bool,
      );
}

class ReadingSettingsService {
  final http.Client client;

  ReadingSettingsService({http.Client? client})
    : client = client ?? http.Client();

  Future<ReadingSettings?> getSettings(String authToken) async {
    try {
      final response = await client.get(
        Uri.parse(ApiRoutes.readingSettings),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final data = responseData['data'] ?? responseData;
        return ReadingSettings.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveSettings(ReadingSettings settings, String authToken) async {
    try {
      final response = await client.put(
        Uri.parse(ApiRoutes.readingSettings),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(settings.toJson()),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
}
