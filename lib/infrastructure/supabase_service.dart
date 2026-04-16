import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/features/defect_reporting/data/models/report_model.dart';

class SupabaseService {

  static const String supabaseUrl = 'https://mvywylhlmktejvsmcqkk.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12eXd5bGhsbWt0ZWp2c21jcWtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxMTk1NzYsImV4cCI6MjA5MDY5NTU3Nn0.qv1mqv8FW83Z_btolYWYEN5fGTXMW8-V08ZphvO3Dv8';

  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  SupabaseClient get client => Supabase.instance.client;

  static bool get isConfigured =>
      supabaseUrl != 'https://YOUR_PROJECT_ID.supabase.co' &&
      supabaseAnonKey != 'YOUR_ANON_KEY';

  static bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool get isReady => isConfigured && isInitialized;

  Future<String?> syncReport(ReportModel report) async {
    if (!isReady) return null;
    try {

      String? imageUrl;
      String? fallbackBase64;
      if (report.imageBase64 != null && report.imageBase64!.isNotEmpty) {
        imageUrl = await _uploadReportImage(
          report.imageBase64!,
          report.id?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
        );
        if (imageUrl == null) {
          fallbackBase64 = report.imageBase64;
          debugPrint('⚠️ Storage 上傳失敗，圖片改以 base64 存入 DB');
        } else {
          debugPrint('✅ 圖片已上傳 Storage: $imageUrl');
        }
      }

      final data = {
        'local_id': report.id,
        'title': report.title,
        'description': report.description,
        'category': report.category,
        'severity': report.severity,
        'risk_level': report.riskLevel,
        'risk_score': report.riskScore,
        'is_urgent': report.isUrgent,
        'status': report.status,
        'image_url': imageUrl,
        'image_base64': fallbackBase64,
        'location': report.location,
        'latitude': report.latitude,
        'longitude': report.longitude,
        'ai_analysis': report.aiAnalysis,
        'company_notes': report.companyNotes,
        'created_at': report.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await client
          .from('reports')
          .upsert(data, onConflict: 'local_id')
          .select('id')
          .single();

      final cloudId = response['id'].toString();
      debugPrint('✅ Supabase: 報告已同步，雲端 id=$cloudId');
      return cloudId;
    } catch (e) {
      debugPrint('❌ Supabase syncReport 失敗: $e');
      return null;
    }
  }

  Future<int> syncBatch(List<ReportModel> reports) async {
    if (!isReady) return 0;
    int count = 0;
    for (final report in reports) {
      final result = await syncReport(report);
      if (result != null) count++;
    }
    debugPrint('✅ Supabase: 批次同步完成 $count/${reports.length} 筆');
    return count;
  }

  Future<List<Map<String, dynamic>>> fetchAllReports() async {
    if (!isReady) return [];
    try {
      final response = await client
          .from('reports')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Supabase fetchAllReports 失敗: $e');
      return [];
    }
  }

  Future<ReportModel?> createReport(ReportModel report,
      {String? imageBase64}) async {
    if (!isReady) return null;
    try {

      String? imageUrl;
      String? fallbackBase64;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        imageUrl = await _uploadReportImage(
          imageBase64,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
        if (imageUrl == null) {

          fallbackBase64 = imageBase64;
          debugPrint('⚠️ Storage 上傳失敗，圖片改以 base64 存入 DB');
        } else {
          debugPrint('✅ 圖片已上傳 Storage: $imageUrl');
        }
      }

      final data = {
        'title': report.title,
        'description': report.description,
        'category': report.category,
        'severity': report.severity,
        'risk_level': report.riskLevel,
        'risk_score': report.riskScore,
        'is_urgent': report.isUrgent,
        'status': report.status,
        'image_url': imageUrl,
        'image_base64': fallbackBase64,
        'location': report.location,
        'latitude': report.latitude,
        'longitude': report.longitude,
        'ai_analysis': report.aiAnalysis,
        'created_at': report.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response =
          await client.from('reports').insert(data).select().single();
      debugPrint('✅ Supabase: 新報告建立成功 id=${response['id']}');
      return mapToReportModel(response);
    } catch (e) {
      debugPrint('❌ Supabase createReport 失敗: $e');
      return null;
    }
  }

  Future<bool> submitWorkerResponse(
      int reportId, String responseText, String? imageBase64) async {
    if (!isReady) return false;
    try {

      String? responseImageUrl;
      String? fallbackBase64;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        responseImageUrl = await _uploadReportImage(
          imageBase64,
          'response_${reportId}_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (responseImageUrl == null) {
          fallbackBase64 = imageBase64;
          debugPrint('⚠️ 回覆圖片 Storage 上傳失敗，改用 base64');
        } else {
          debugPrint('✅ 回覆圖片已上傳: $responseImageUrl');
        }
      }

      final existing = await client
          .from('reports')
          .select('conversation')
          .eq('id', reportId)
          .single();

      List<dynamic> conv = [];
      if (existing['conversation'] != null &&
          (existing['conversation'] as String).isNotEmpty) {
        try {
          conv = jsonDecode(existing['conversation'] as String);
        } catch (_) {}
      }

      conv.add({
        'sender': 'worker',
        'text': responseText,
        'image': responseImageUrl ?? fallbackBase64,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await client.from('reports').update({
        'worker_response': responseText,
        'worker_response_image': responseImageUrl ?? fallbackBase64,
        'conversation': jsonEncode(conv),
        'has_unread_company': false,
        'status': 'in_progress',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);

      debugPrint('✅ 工人回覆已提交，狀態更新為處理中');
      return true;
    } catch (e) {
      debugPrint('❌ submitWorkerResponse 失敗: $e');
      return false;
    }
  }

  Future<bool> addCompanyMessage(int reportId, String messageText) async {
    if (!isReady) return false;
    try {

      final existing = await client
          .from('reports')
          .select('conversation')
          .eq('id', reportId)
          .single();

      List<dynamic> conv = [];
      if (existing['conversation'] != null &&
          (existing['conversation'] as String).isNotEmpty) {
        try {
          conv = jsonDecode(existing['conversation'] as String);
        } catch (_) {}
      }

      conv.add({
        'sender': 'company',
        'text': messageText,
        'image': null,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await client.from('reports').update({
        'company_notes': messageText,
        'conversation': jsonEncode(conv),
        'has_unread_company': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);

      debugPrint('✅ 公司訊息已添加');
      return true;
    } catch (e) {
      debugPrint('❌ addCompanyMessage 失敗: $e');
      return false;
    }
  }

  Future<void> clearUnreadCompany(int reportId) async {
    if (!isReady) return;
    try {
      await client.from('reports').update({
        'has_unread_company': false,
      }).eq('id', reportId);
    } catch (e) {
      debugPrint('❌ clearUnreadCompany 失敗: $e');
    }
  }

  static ReportModel mapToReportModel(Map<String, dynamic> data) {
    return ReportModel(
      id: (data['id'] as num?)?.toInt(),
      title: data['title'] as String? ?? '未命名',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'structural',
      severity: data['severity'] as String? ?? 'moderate',
      riskLevel: data['risk_level'] as String? ?? 'low',
      riskScore: (data['risk_score'] as num?)?.toInt() ?? 0,
      isUrgent: data['is_urgent'] == true,
      status: data['status'] as String? ?? 'pending',
      imageUrl: data['image_url'] as String?,
      imageBase64: data['image_base64'] as String?,
      location: data['location'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      aiAnalysis: data['ai_analysis'] as String?,
      companyNotes: data['company_notes'] as String?,
      workerResponse: data['worker_response'] as String?,
      workerResponseImage: data['worker_response_image'] as String?,
      conversation: ReportModel.conversationFromJson(data['conversation']),
      hasUnreadCompany: data['has_unread_company'] == true,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'] as String)
          : null,
      synced: true,
    );
  }

  Future<bool> deleteReport(int localId) async {
    if (!isReady) return false;
    try {
      await client.from('reports').delete().eq('local_id', localId);
      debugPrint('✅ Supabase: 已刪除報告 local_id=$localId');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase deleteReport 失敗: $e');
      return false;
    }
  }

  Future<bool> upsertInspectionSession(Map<String, dynamic> sessionJson) async {
    if (!isReady) return false;
    try {
      final payload = Map<String, dynamic>.from(sessionJson);
      final sessionId = payload['id']?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        debugPrint('❌ upsertInspectionSession: 缺少 session id');
        return false;
      }

      final createdAt = payload['createdAt']?.toString();
      final updatedAt = payload['updatedAt']?.toString();

      await client.from('inspection_sessions').upsert({
        'session_id': sessionId,
        'name': payload['name'],
        'project_id': payload['projectId'],
        'floor': payload['floor'],
        'floor_plan_path': payload['floorPlanPath'],
        'status': payload['status'],
        'payload': payload,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
        'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      }, onConflict: 'session_id');

      return true;
    } catch (e) {
      debugPrint('❌ upsertInspectionSession 失敗: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchInspectionSessions() async {
    if (!isReady) return [];
    try {
      final rows = await client
          .from('inspection_sessions')
          .select('payload')
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows)
          .map((row) => Map<String, dynamic>.from(
              row['payload'] as Map<String, dynamic>? ?? {}))
          .where((payload) => payload.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('❌ fetchInspectionSessions 失敗: $e');
      return [];
    }
  }

  Future<bool> deleteInspectionSession(String sessionId) async {
    if (!isReady) return false;
    try {
      await client
          .from('inspection_sessions')
          .delete()
          .eq('session_id', sessionId);
      return true;
    } catch (e) {
      debugPrint('❌ deleteInspectionSession 失敗: $e');
      return false;
    }
  }

  Future<String?> uploadFloorPlan({
    required String buildingId,
    required int floor,
    required Uint8List imageBytes,
    String extension = 'png',
  }) async {
    if (!isReady) return null;
    try {
      final path = 'buildings/$buildingId/floor_$floor.$extension';
      await client.storage.from('floor-plans').uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = client.storage.from('floor-plans').getPublicUrl(path);
      debugPrint('✅ Supabase: 樓層圖已上傳 → $url');
      return url;
    } catch (e) {
      debugPrint('❌ Supabase uploadFloorPlan 失敗: $e');
      return null;
    }
  }

  String? getFloorPlanUrl(String buildingId, int floor,
      [String extension = 'png']) {
    if (!isReady) return null;
    final path = 'buildings/$buildingId/floor_$floor.$extension';
    return client.storage.from('floor-plans').getPublicUrl(path);
  }

  Future<Uint8List?> downloadFloorPlan(String buildingId, int floor,
      [String extension = 'png']) async {
    if (!isReady) return null;
    try {
      final path = 'buildings/$buildingId/floor_$floor.$extension';
      final bytes = await client.storage.from('floor-plans').download(path);
      debugPrint('✅ Supabase: 樓層圖已下載 (${bytes.length} bytes)');
      return bytes;
    } catch (e) {
      debugPrint('❌ Supabase downloadFloorPlan 失敗: $e');
      return null;
    }
  }

  Future<List<FileObject>> listFloorPlans(String buildingId) async {
    if (!isReady) return [];
    try {
      return await client.storage
          .from('floor-plans')
          .list(path: 'buildings/$buildingId');
    } catch (e) {
      debugPrint('❌ Supabase listFloorPlans 失敗: $e');
      return [];
    }
  }

  Future<String?> uploadImageForAnalysis(String imageBase64) async {
    if (!isReady) return null;
    try {
      final bytes = base64Decode(imageBase64);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'analysis/ai_temp_$timestamp.jpg';
      await client.storage.from('report-images').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      final url = client.storage.from('report-images').getPublicUrl(path);
      debugPrint('✅ Supabase AI 分析圖片 URL: $url');
      return url;
    } catch (e) {
      debugPrint('⚠️ Supabase uploadImageForAnalysis 失敗: $e');
      return null;
    }
  }

  Future<String?> _uploadReportImage(String base64, String reportId) async {
    if (!isReady) return null;
    try {
      final bytes = base64Decode(base64);
      final path = 'reports/report_$reportId.jpg';
      await client.storage.from('report-images').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      return client.storage.from('report-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('⚠️ Supabase 圖片上傳失敗（非致命）: $e');
      return null;
    }
  }
}
