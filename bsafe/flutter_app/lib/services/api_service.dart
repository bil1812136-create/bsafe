import 'dart:convert';
import 'package:http/http.dart' as http;
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
        print('Failed to sync report ${report.id}: $e');
      }
    }
  }

  // ==================== POE AI Analysis API ====================

  /// Analyze image using POE API for building damage assessment
  Future<Map<String, dynamic>> analyzeImageWithAI(String imageBase64) async {
    try {
      // Create a simplified prompt for AI analysis
      const prompt = '''
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
              'content': prompt,
            }
          ],
        }),
      );

      print('POE API Response Status: ${response.statusCode}');
      print('POE API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Extract text from response
        String text = '';
        if (responseData is Map && responseData.containsKey('text')) {
          text = responseData['text'];
        } else if (responseData is Map && responseData.containsKey('data')) {
          text = responseData['data'].toString();
        } else {
          text = response.body;
        }
        
        // Try to extract JSON from the response
        final jsonMatch = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}').firstMatch(text);
        if (jsonMatch != null) {
          try {
            return jsonDecode(jsonMatch.group(0)!);
          } catch (e) {
            print('Failed to parse JSON: $e');
          }
        }
        
        // If no valid JSON found, return a default response
        print('No valid JSON found in response, using fallback');
        throw Exception('Invalid AI response format');
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('AI analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      print('AI Analysis Error: $e');
      throw Exception('AI analysis error: $e');
    }
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
