import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DefectClassifierService {
  static const String _geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _geminiModel = 'gemini-2.5-flash';
  static const String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const List<String> supportedLabels = [
    'Crack on Wall',
    'Delamination of Surface Coating',
    'Peeling off of Paint',
    'Water Stain',
    'Unknown',
    'Other',
  ];

  Future<String> classifyDefect(Uint8List bytes) async {
    if (_geminiApiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is empty');
    }

    final imageBase64 = base64Encode(bytes);
    final uri = Uri.parse(
      '$_geminiApiUrl/$_geminiModel:generateContent?key=$_geminiApiKey',
    );

    const prompt = '''
You are a building defect classifier.
Analyze the image and return exactly ONE label from this list:
  Crack on Wall
  Delamination of Surface Coating
  Peeling off of Paint
  Water Stain
  Unknown
Other

Rules:
- Output only the label text.
- No explanation.
  - If image is blurry/dark/unclear, output Unknown.
''';

    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt},
                  {
                    'inline_data': {
                      'mime_type': 'image/jpeg',
                      'data': imageBase64,
                    },
                  },
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0,
              'maxOutputTokens': 16,
              'thinkingConfig': {
                'thinkingBudget': 0,
              },
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      if (response.body
          .contains('User location is not supported for the API use')) {
        return 'Unknown';
      }
      throw Exception('Gemini API ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      return 'Other';
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    final raw = parts.isNotEmpty ? (parts.first['text']?.toString() ?? '') : '';

    final cleaned = raw.trim().replaceAll('*', '').replaceAll('`', '');
    final singleLine = cleaned.split('\n').first.trim();

    for (final label in supportedLabels) {
      if (singleLine.toLowerCase() == label.toLowerCase()) {
        return label;
      }
    }

    for (final label in supportedLabels) {
      if (singleLine.toLowerCase().contains(label.toLowerCase())) {
        return label;
      }
    }

    final lower = singleLine.toLowerCase();
    if (lower.contains('crack')) return 'Crack on Wall';
    if (lower.contains('delamination') ||
        lower.contains('surface coating') ||
        lower.contains('coating detached') ||
        lower.contains('coating debond')) {
      return 'Delamination of Surface Coating';
    }
    if (lower.contains('peeling') ||
        lower.contains('paint peel') ||
        lower.contains('flaking paint')) {
      return 'Peeling off of Paint';
    }
    if (lower.contains('water stain') ||
        lower.contains('damp stain') ||
        lower.contains('moisture stain') ||
        lower.contains('leak mark')) {
      return 'Water Stain';
    }
    if (lower.contains('unknown') ||
        lower.contains('unsure') ||
        lower.contains('cannot determine') ||
        lower.contains('insufficient evidence') ||
        lower.contains('not sure')) {
      return 'Unknown';
    }

    return 'Other';
  }
}
