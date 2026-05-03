import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DefectClassifierService {
  static const String _geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _geminiModel = 'gemini-3.1-pro-preview';
  static const String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const List<String> supportedLabels = [
    'efflorescence',
    'peeling paint',
    'Wall crack',
    'spalling',
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
  efflorescence
  peeling paint
  Wall crack
  spalling
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
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      if (response.body
          .contains('User location is not supported for the API use')) {
        return 'Unknown';
      }
      throw Exception(
          'Gemini API ${response.statusCode}: ${_extractApiError(response.body)}');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      if (kDebugMode) {
        debugPrint('Gemini returned no candidates. body=${response.body}');
      }
      return 'Unknown';
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    final texts = parts
        .map((p) => (p as Map<String, dynamic>)['text']?.toString() ?? '')
        .where((t) => t.trim().isNotEmpty)
        .toList();
    final raw = texts.join('\n');

    final cleaned = raw.trim().replaceAll('*', '').replaceAll('`', '');
    final singleLine = cleaned.split('\n').first.trim();
    if (kDebugMode) {
      debugPrint('Gemini raw label response: "$singleLine"');
    }
    if (singleLine.isEmpty) {
      return 'Unknown';
    }

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
    // Fallback keyword mapping: MUST return one of supportedLabels only.
    if (lower.contains('crack') || lower.contains('裂') || lower.contains('裂縫')) {
      return 'Wall crack';
    }
    if (lower.contains('spall') ||
        lower.contains('spalling') ||
        lower.contains('concrete spall') ||
        lower.contains('exposed rebar') ||
        lower.contains('剝落') ||
        lower.contains('露筋')) {
      return 'spalling';
    }
    if (lower.contains('efflorescence') ||
        lower.contains('salt') ||
        lower.contains('salts') ||
        lower.contains('white deposit') ||
        lower.contains('white powder') ||
        lower.contains('crystall') ||
        lower.contains('白華') ||
        lower.contains('鹽析')) {
      return 'efflorescence';
    }
    if (lower.contains('delamination') ||
        lower.contains('surface coating') ||
        lower.contains('coating detached') ||
        lower.contains('coating debond') ||
        lower.contains('peeling') ||
        lower.contains('paint peel') ||
        lower.contains('flaking paint') ||
        lower.contains('油漆剝落')) {
      return 'peeling paint';
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

  String _extractApiError(String body) {
    try {
      final parsed = jsonDecode(body);
      final error = parsed['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Ignore JSON parse failure and fallback to raw body.
    }
    return body;
  }
}
