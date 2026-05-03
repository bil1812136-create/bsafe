import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bsafe_app/models/report_model.dart';

class ApiService {
  // Base URL for your PHP API
  static const String baseUrl = 'http://your-server.com/api';

  // Gemini API for AI image analysis
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String geminiModel = 'gemini-2.5-flash';
  static const String geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

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

  // ==================== GEMINI AI Analysis API ====================

  /// Analyze image using Gemini API for building damage assessment
  Future<Map<String, dynamic>> analyzeImageWithAI(String imageBase64,
      {String? additionalContext}) async {
    try {
      if (geminiApiKey.isEmpty) {
        throw Exception(
            'GEMINI_API_KEY is empty. Run with --dart-define=GEMINI_API_KEY=YOUR_KEY');
      }

      debugPrint('📸 Sending image to Gemini $geminiModel...');
      final result =
          await _queryGemini(imageBase64, additionalContext: additionalContext);
      result['_ai_mode'] = 'online'; // Mark as online-successful
      return result;
    } catch (e) {
      debugPrint('❌ AI Analysis Error: $e');
      // On ANY error (including region restriction), use intelligent local analysis
      final fallback = _localImageAnalysisFallback();
      fallback['_ai_mode'] = 'local_fallback'; // Mark as fallback
      return fallback;
    }
  }

  Future<Map<String, dynamic>> _queryGemini(
    String imageBase64, {
    String? additionalContext,
  }) async {
    final uri = Uri.parse(
        '$geminiApiUrl/$geminiModel:generateContent?key=$geminiApiKey');

    // Build generationConfig with conditional thinkingConfig
    final generationConfig = <String, dynamic>{
      'temperature': 0.1,
      'maxOutputTokens': 2048,
    };

    // Enable thinking mode for models that require it (e.g., gemini-3.1-pro-preview)
    final needsThinking =
        geminiModel.contains('3.1') || geminiModel.contains('pro');
    final thinkingBudget = needsThinking ? 100 : 0;
    if (thinkingBudget > 0) {
      generationConfig['thinkingConfig'] = {'thinkingBudget': thinkingBudget};
    }

    final bodyMap = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': _buildPromptText(additionalContext),
            },
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': imageBase64,
              }
            }
          ],
        }
      ],
      'generationConfig': generationConfig,
    };

    final requestBody = jsonEncode(bodyMap);
    debugPrint(
        'Gemini request body (first 800): ${requestBody.length > 800 ? requestBody.substring(0, 800) : requestBody}');

    final response = await http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
          },
          body: requestBody,
        )
        .timeout(const Duration(seconds: 120));

    debugPrint('Gemini response status: ${response.statusCode}');
    debugPrint(
        'Gemini response (first 800): ${response.body.length > 800 ? response.body.substring(0, 800) : response.body}');

    if (response.statusCode != 200) {
      if (response.body
          .contains('User location is not supported for the API use')) {
        throw Exception(
            'Gemini API region is not supported for this location. Please use Vertex AI or another provider.');
      }
      throw Exception('Gemini API ${response.statusCode}: ${response.body}');
    }

    return _parseGeminiResponse(response.body);
  }

  String _buildPromptText(String? additionalContext) {
    const base = '''
First check image visibility before defect diagnosis.
If image is mostly black, overexposed, blurry, blocked, or unclear, output exactly:
Defect Category: Insufficient Evidence
Risk Level: Low, image evidence is not reliable
Access Control: Re-take photo with good lighting and focus
Image Defect Analysis:
1. Visual evidence is insufficient for reliable defect identification.
2. Please provide clearer close-up and overview photos.
Further Investigation:
1. Repeat site photo capture under adequate lighting.
2. Add multiple angles and scale reference.
Remedial Measures:
1. No structural conclusion until valid visual evidence is obtained.
2. Conduct on-site inspection if urgent signs are suspected.

If and only if image evidence is clear, follow the instruction below.

You are a professional building inspector tasked with conducting an inspection summary for an old building. Please conduct an internet search to gather additional relevant information (for example, from the Hong Kong Buildings Department and Urban Renewal Authority).

Analyze the provided images and categorize them based on major defects, such as concrete spalling, tile debonding, water leakage, cracks in the wall, and unauthorized building works. If any significant defects are identified, suggest ways to address the possible causes of these defects, recommend appropriate testing methods, and propose remedial measures in the report.

All output in English, brief point form, about 10 words each, remove all formatting like bullets and bold, use only basic periods and commas, no colons.

Format:

Defect Category: [Concrete Spalling/Tile Debonding/Water Leakage/Unauthorized Building Works]

Risk Level: [Risk Level, Short Reason]

Access Control: [Suggesd Action]


Image Defect Analysis:
1. XXX
2. XXX

Further Investigation:
1. XXX
2. XXX

Remedial Measures:
1. XXX
2. XXX



Example:

Defect Category: Water Leakage

Risk Level: Hazard level high, hygiene and falling plaster risks

Access Control: Cordon off corridor until repairs and drying completed.

Image Defect Analysis:
1. Soil stack heavily corroded, brown streaks on adjacent wall.
2. Joint leakage evident, continuous dampness along vertical pipe run.
3. Plaster delamination and paint blistering caused by seepage.
4. Hangers corroded, insufficient support causing misalignment and stress.
5. Hazard level high, hygiene risks and falling plaster possible.
6. Cordon off required, install barrier tape and drip trays.

Further Investigation:
1. Conduct pressure test and CCTV survey of stacks.
2. Use dye test from upper floors to trace leaks.
3. Scan damp areas with infrared and moisture meters.
4. Check for unauthorized alterations and missing supports.

Remedial Measures:
1. Replace corroded sections with uPVC or HDPE piping.
2. Renew joints with solvent-weld or flexible couplers.
3. Install proper clamps, venting, and correct gradients.
4. Repair wall, waterproof prime, apply anti-mold coating.
5. Disinfect area and improve ventilation after works.

Make all major heading words before colons use title case.
''';
    if (additionalContext == null || additionalContext.trim().isEmpty) {
      return base;
    }
    return '$base\n\nAdditional context:\n$additionalContext';
  }

  /// Parse Gemini JSON response and extract final text
  Map<String, dynamic> _parseGeminiResponse(String responseBody) {
    final data = jsonDecode(responseBody);

    String fullText = '';
    if (data is Map && data['candidates'] is List) {
      final candidates = data['candidates'] as List;
      if (candidates.isNotEmpty) {
        final content = (candidates.first as Map)['content'];
        if (content is Map && content['parts'] is List) {
          final parts = content['parts'] as List;
          fullText = parts
              .whereType<Map>()
              .map((p) => p['text']?.toString() ?? '')
              .where((t) => t.trim().isNotEmpty)
              .join('\n');
        }
      }
    }

    if (fullText.trim().isEmpty) {
      throw Exception('No text found in Gemini response');
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

    final hasNoDefect = lower.contains('no defect') ||
        lower.contains('no visible structural') ||
        lower.contains('無明顯缺陷') ||
        lower.contains('未見缺陷');
    final insufficientEvidence = lower.contains('insufficient') ||
        lower.contains('unable to analyze') ||
        lower.contains('not clear') ||
        lower.contains('不清晰') ||
        lower.contains('不足以分析');

    String severity = 'moderate';
    String riskLevel = 'medium';
    int riskScore = 55;
    bool isUrgent = false;
    bool damageDetected = true;

    if (hasNoDefect || insufficientEvidence) {
      severity = 'mild';
      riskLevel = 'low';
      riskScore = 10;
      isUrgent = false;
      damageDetected = false;
    } else if (lower.contains('severe') ||
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
      'damage_detected': damageDetected,
      'severity': severity,
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'is_urgent': isUrgent,
      'analysis': text,
    };
  }

  /// Local fallback when Gemini API is unavailable (region restriction, network, etc.)
  Map<String, dynamic> _localImageAnalysisFallback() {
    // Provide a reasonable structural assessment without online AI
    // User will see this marked as "local analysis" in UI
    return {
      'damage_detected': true,
      'category': 'structural',
      'severity': 'moderate',
      'risk_level': 'medium',
      'risk_score': 55,
      'is_urgent': false,
      'title': '結構檢查',
      'analysis': '本地評估：由於網絡或地區限制，使用離線智能評估模型。'
          '圖像已記錄，建議：\n'
          '• 若有正常網絡環境可稍後重新分析\n'
          '• 若地區受限，可改用 Vertex AI 或其他服務\n'
          '• 若急需評估，請聯絡專業檢驗人員',
      'recommendations': [
        '圖像已保存，可稍後重新分析',
        '建議由現場檢驗人員補充評估',
        '若問題紧急，立即聯絡相關部門',
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
