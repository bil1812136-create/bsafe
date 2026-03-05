import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:bsafe_app/models/report_model.dart';

class ApiService {
  // Base URL for your PHP API
  static const String baseUrl = 'http://your-server.com/api';

  // POE API for AI image analysis
  static const String poeApiKey = 'HTLbuegNjtBmxNX5rWeH7cyxFfNc1oANBPRtdY_aO4E';
  static const String poeBotName = 'B-SAFE'; // Your POE bot name
  static const String poeApiUrl = 'https://api.poe.com/bot/';

  // Singleton pattern
  static final ApiService instance = ApiService._init();
  ApiService._init();

  // Headers for API requests
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ==================== Report API ====================

  // Submit a new report
  Future<Map<String, dynamic>> submitReport(ReportModel report) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: _headers,
        body: jsonEncode(report.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to submit report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get all reports from server
  Future<List<ReportModel>> getReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ReportModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get reports: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update report status
  Future<Map<String, dynamic>> updateReportStatus(int id, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/reports/$id'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Sync pending reports
  Future<void> syncReports(List<ReportModel> reports) async {
    for (final report in reports) {
      try {
        await submitReport(report);
      } catch (e) {
        // Log error but continue with other reports
        debugPrint('Failed to sync report ${report.id}: $e');
      }
    }
  }

  // ==================== POE AI Analysis API ====================

  /// Step 1: Upload image to get a public URL (tries catbox.moe first, then 0x0.st)
  Future<String> _uploadImageToPublicHost(String imageBase64) async {
    debugPrint('⬆️ Uploading image to get public URL...');
    final bytes = base64Decode(imageBase64);

    // Try catbox.moe first (more reliable)
    try {
      debugPrint('🔄 Trying catbox.moe...');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://catbox.moe/user/api.php'),
      );
      request.fields['reqtype'] = 'fileupload';
      request.files.add(http.MultipartFile.fromBytes(
        'fileToUpload',
        bytes,
        filename: 'building_photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final responseText = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200 && responseText.startsWith('https://')) {
        final url = responseText.trim();
        debugPrint('✅ Image uploaded (catbox.moe): $url');
        return url;
      }
      debugPrint(
          '⚠️ catbox.moe failed: ${streamed.statusCode} - $responseText');
    } catch (e) {
      debugPrint('⚠️ catbox.moe error: $e');
    }

    // Fallback: try 0x0.st
    debugPrint('🔄 Trying 0x0.st as fallback...');
    final request2 = http.MultipartRequest(
      'POST',
      Uri.parse('https://0x0.st/'),
    );
    request2.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: 'building_photo.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamed2 =
        await request2.send().timeout(const Duration(seconds: 30));
    final responseText2 = await streamed2.stream.bytesToString();

    if (streamed2.statusCode == 200) {
      final url = responseText2.trim();
      debugPrint('✅ Image uploaded (0x0.st): $url');
      return url;
    }
    throw Exception(
        'All upload services failed. Last: ${streamed2.statusCode} - $responseText2');
  }

  /// Analyze image using POE API for building damage assessment
  Future<Map<String, dynamic>> analyzeImageWithAI(String imageBase64,
      {String? additionalContext}) async {
    try {
      // Create a simplified prompt for AI analysis
      String prompt = '''
請分析建築物損壞情況並評估風險。

根據用戶提供的資訊，請進行以下評估：
1. 識別損壞類型（結構性損壞、外觀損壞、電氣問題、水管問題等）
2. 評估損壞嚴重程度（輕微 mild/中度 moderate/嚴重 severe）
3. 判斷風險等級（低 low/中 medium/高 high）
4. 計算風險評分（0-100分）
5. 是否需要緊急處理（true/false）
6. 提供處理建議

請以JSON格式返回，格式如下：
{
  "damage_detected": true,
  "damage_types": ["裂縫", "剝落"],
  "severity": "moderate",
  "risk_level": "medium",
  "risk_score": 65,
  "is_urgent": false,
  "analysis": "發現中度損壞，建議盡快處理",
  "recommendations": ["安排專業檢查", "監控是否惡化"]
}

注意：只返回JSON，不要包含其他文字。
''';

      if (additionalContext != null && additionalContext.isNotEmpty) {
        prompt += '\n用戶補充資訊：$additionalContext\n請根據以上補充資訊重新評估。';
      }

      // Send request to POE API
      final response = await http.post(
        Uri.parse('https://api.poe.com/bot/$poeBotName'),
        headers: {
          'Authorization': 'Bearer $poeApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': '1.0',
          'type': 'query',
          'query': [
            {
              'role': 'user',
              'content': imageUrl,
              'content_type': 'text/markdown',
              'timestamp': 0,
              'message_id': '',
              'feedback': [],
              'attachments': [],
              'parameters': {},
              'sender': null,
              'sender_id': null,
              'metadata': null,
              'message_type': null,
              'referenced_message': null,
              'reactions': [],
            }
          ],
          'user_id': '',
          'conversation_id': '',
          'message_id': '',
          'metadata': '',
          'api_key': '<missing>',
          'access_key': '<missing>',
          'temperature': null,
          'skip_system_prompt': false,
          'logit_bias': {},
          'stop_sequences': [],
          'language_code': 'zh-Hant',
          'adopt_current_bot_name': null,
          'bot_query_id': '',
          'users': [],
          'tools': null,
          'tool_calls': null,
          'tool_results': null,
          'query_creation_time': null,
          'extra_params': null,
        });

        final streamedResponse =
            await client.send(request).timeout(const Duration(seconds: 180));
        final responseBody = await streamedResponse.stream.bytesToString();

        debugPrint('Poe response status: ${streamedResponse.statusCode}');
        debugPrint(
            'Poe response (first 800): ${responseBody.length > 800 ? responseBody.substring(0, 800) : responseBody}');

        if (streamedResponse.statusCode == 200) {
          return _parsePoeSSE(responseBody);
        }
        throw Exception(
            'Poe API ${streamedResponse.statusCode}: $responseBody');
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('❌ AI Analysis Error: $e');
      return _localImageAnalysisFallback();
    }
  }

  /// Parse Poe SSE response and accumulate full AI text
  Map<String, dynamic> _parsePoeSSE(String responseBody) {
    String accumulatedText = '';
    String lastReplace = '';
    String currentEvent = '';

    for (final rawLine in responseBody.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        final dataStr = line.substring(5).trim();
        if (dataStr.isEmpty || dataStr == '{}') continue;

        // Handle error events from Poe
        if (currentEvent == 'error') {
          try {
            final data = jsonDecode(dataStr);
            throw Exception('Poe error: ${data['text']}');
          } catch (e) {
            if (e.toString().contains('Poe error')) rethrow;
            throw Exception('Poe error: $dataStr');
          }
        }

        try {
          final data = jsonDecode(dataStr);
          if (data is Map && data.containsKey('text')) {
            final t = data['text'].toString();
            // Skip "Thinking..." status messages
            if (t.startsWith('Thinking...')) continue;
            if (currentEvent == 'replace_response') {
              lastReplace = t;
            } else if (currentEvent == 'text') {
              accumulatedText += t;
            }
          }
        } catch (_) {}
      }
    }

    // Prefer accumulated text events; fall back to last replace_response
    final fullText = accumulatedText.isNotEmpty ? accumulatedText : lastReplace;

    if (fullText.isEmpty) {
      throw Exception('No text found in Poe SSE response');
    }

    debugPrint(
        'AI full text (first 200): ${fullText.length > 200 ? fullText.substring(0, 200) : fullText}');
    return _buildResultFromText(fullText);
  }

  /// Build a structured result map from the AI full response text.
  /// Directly places the AI response in 'analysis' for display.
  Map<String, dynamic> _buildResultFromText(String text) {
    debugPrint('🔍 Building result from text (${text.length} chars)');

    // Simple keyword-based risk detection from AI response
    final lower = text.toLowerCase();

    String severity = 'moderate';
    String riskLevel = 'medium';
    int riskScore = 55;
    bool isUrgent = false;

    if (lower.contains('severe') ||
        lower.contains('嚴重') ||
        lower.contains('危險') ||
        lower.contains('高風險') ||
        lower.contains('立即')) {
      severity = 'severe';
      riskLevel = 'high';
      riskScore = 85;
      isUrgent = true;
    } else if (lower.contains('mild') ||
        lower.contains('輕微') ||
        lower.contains('低風險') ||
        lower.contains('minor')) {
      severity = 'mild';
      riskLevel = 'low';
      riskScore = 25;
    }

    return {
      'damage_detected': true,
      'severity': severity,
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'is_urgent': isUrgent,
      'analysis': text,
    };
  }

  /// Local fallback when Poe API is unavailable
  Map<String, dynamic> _localImageAnalysisFallback() {
    return {
      'damage_detected': true,
      'category': 'structural',
      'severity': 'moderate',
      'risk_level': 'medium',
      'risk_score': 50,
      'is_urgent': false,
      'title': '建築安全問題',
      'analysis': 'AI 分析服務暫時不可用（請確認網絡連線）。照片已保存，請稍後重新分析。',
      'recommendations': [
        '請確認網絡連線後重試',
        '建議安排專業人員現場檢查',
      ],
    };
  }

  /// Local fallback analysis when offline or AI unavailable
  static Map<String, dynamic> localAnalysis(String severity, String category) {
    // Simple rule-based assessment
    int riskScore;
    String riskLevel;
    bool isUrgent;

    switch (severity) {
      case 'severe':
        riskScore = 80 + (category == 'structural' ? 15 : 5);
        riskLevel = 'high';
        isUrgent = true;
        break;
      case 'moderate':
        riskScore = 50 + (category == 'structural' ? 20 : 10);
        riskLevel = riskScore >= 70 ? 'high' : 'medium';
        isUrgent = category == 'structural';
        break;
      case 'mild':
      default:
        riskScore = 20 + (category == 'structural' ? 15 : 5);
        riskLevel = 'low';
        isUrgent = false;
    }

    return {
      'damage_detected': true,
      'severity': severity,
      'risk_level': riskLevel,
      'risk_score': riskScore.clamp(0, 100),
      'is_urgent': isUrgent,
      'analysis': '基於用戶輸入的本地評估（離線模式）',
      'recommendations': _getRecommendations(severity, category),
    };
  }

  static List<String> _getRecommendations(String severity, String category) {
    final List<String> recommendations = [];

    if (severity == 'severe') {
      recommendations.add('立即通知相關部門');
      recommendations.add('建議暫時封閉受影響區域');
      recommendations.add('盡快安排專業檢查');
    } else if (severity == 'moderate') {
      recommendations.add('安排專業人員檢查');
      recommendations.add('監控問題是否惡化');
    } else {
      recommendations.add('定期監控情況');
      recommendations.add('安排例行維護');
    }

    switch (category) {
      case 'structural':
        recommendations.add('聯繫結構工程師評估');
        break;
      case 'exterior':
        recommendations.add('檢查外牆防水情況');
        break;
      case 'electrical':
        recommendations.add('切勿觸碰，聯繫電工處理');
        break;
      case 'plumbing':
        recommendations.add('關閉相關水閥，聯繫水電師傅');
        break;
    }

    return recommendations;
  }
}
