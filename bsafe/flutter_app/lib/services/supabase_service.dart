import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/models/report_model.dart';

/// Supabase 雲端同步服務
///
/// ════════════════════════════════════════════════════════════
/// 🔧 SETUP — 第一次使用請按以下步驟設定：
///
/// 1. 前往 https://supabase.com → 免費註冊 → New Project
///
/// 2. 在 Supabase Dashboard → SQL Editor 執行以下 SQL 建立資料表：
///
///    -- AI 分析報告表（包含多輪對話支持）
///    CREATE TABLE reports (
///      id                    BIGSERIAL PRIMARY KEY,
///      local_id              INTEGER,
///      title                 TEXT NOT NULL,
///      description           TEXT NOT NULL,
///      category              TEXT NOT NULL,
///      severity              TEXT NOT NULL,
///      risk_level            TEXT DEFAULT 'low',
///      risk_score            INTEGER DEFAULT 0,
///      is_urgent             BOOLEAN DEFAULT FALSE,
///      status                TEXT DEFAULT 'pending',
///      image_url             TEXT,
///      image_base64          TEXT,
///      location              TEXT,
///      latitude              DOUBLE PRECISION,
///      longitude             DOUBLE PRECISION,
///      ai_analysis           TEXT,
///      company_notes         TEXT,
///      worker_response       TEXT,
///      worker_response_image TEXT,
///      conversation          JSONB,
///      has_unread_company    BOOLEAN DEFAULT FALSE,
///      created_at            TIMESTAMPTZ DEFAULT NOW(),
///      updated_at            TIMESTAMPTZ DEFAULT NOW(),
///      UNIQUE(local_id)
///    );
///
///    -- 啟用 Realtime 監聽（自動同步對話）
///    ALTER TABLE reports REPLICA IDENTITY FULL;
///    ALTER PUBLICATION supabase_realtime ADD TABLE reports;
///
///    -- 讓匿名用戶可以讀寫（開發用）
///    ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
///    CREATE POLICY "allow_all" ON reports FOR ALL USING (true) WITH CHECK (true);
///
/// 3. Storage → Create Bucket:
///    - 名稱: floor-plans   （Public）
///    - 名稱: report-images （Public）
///
/// 4. Settings → API → 複製 Project URL 和 anon public key
///    填入下方兩個常數即可完成設定。
/// ════════════════════════════════════════════════════════════
class SupabaseService {
  // ── 填入你的 Supabase 專案資料 ──────────────────────────────
  static const String supabaseUrl = 'https://mvywylhlmktejvsmcqkk.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12eXd5bGhsbWt0ZWp2c21jcWtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxMTk1NzYsImV4cCI6MjA5MDY5NTU3Nn0.qv1mqv8FW83Z_btolYWYEN5fGTXMW8-V08ZphvO3Dv8';
  // ───────────────────────────────────────────────────────────

  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  SupabaseClient get client => Supabase.instance.client;

  /// 檢查是否已設定（未設定時所有方法靜默返回 null）
  static bool get isConfigured =>
      supabaseUrl != 'https://YOUR_PROJECT_ID.supabase.co' &&
      supabaseAnonKey != 'YOUR_ANON_KEY';

  // ══════════════════════════════════════════════════════════
  // REPORTS — AI 分析結果雲端同步
  // ══════════════════════════════════════════════════════════

  /// 上傳單筆報告到 Supabase（包含 AI 分析＋圖片）
  Future<String?> syncReport(ReportModel report) async {
    if (!isConfigured) return null;
    try {
      // 先嘗試上傳圖片到 Storage，取得公開 URL
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

  /// 批次同步所有未同步的報告
  Future<int> syncBatch(List<ReportModel> reports) async {
    if (!isConfigured) return 0;
    int count = 0;
    for (final report in reports) {
      final result = await syncReport(report);
      if (result != null) count++;
    }
    debugPrint('✅ Supabase: 批次同步完成 $count/${reports.length} 筆');
    return count;
  }

  /// 從雲端讀取所有報告
  Future<List<Map<String, dynamic>>> fetchAllReports() async {
    if (!isConfigured) return [];
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

  /// 直接在 Supabase 建立新報告（不需要 local_id），回傳包含雲端 id 的 ReportModel
  Future<ReportModel?> createReport(ReportModel report,
      {String? imageBase64}) async {
    if (!isConfigured) return null;
    try {
      // 先嘗試上傳到 Storage，取得公開 URL
      String? imageUrl;
      String? fallbackBase64;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        imageUrl = await _uploadReportImage(
          imageBase64,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
        if (imageUrl == null) {
          // Storage 上傳失敗 → 以 base64 存入資料庫欄位作後備
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

  /// 提交工人回覆（文字 + 圖片）並將狀態改為「處理中」— 添加到 conversation
  Future<bool> submitWorkerResponse(
      int reportId, String responseText, String? imageBase64) async {
    if (!isConfigured) return false;
    try {
      // 嘗試將圖片上傳到 Storage
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

      // 取得現有 conversation
      final existing = await client
          .from('reports')
          .select('conversation')
          .eq('id', reportId)
          .single();

      final conv = _decodeConversation(existing['conversation']);

      // 添加新訊息
      conv.add({
        'sender': 'worker',
        'text': responseText,
        'image': responseImageUrl ?? fallbackBase64,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await client.from('reports').update({
        'worker_response': responseText, // 向後兼容
        'worker_response_image': responseImageUrl ?? fallbackBase64, // 向後兼容
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

  /// 公司端添加對話訊息（跟進任務）
  Future<bool> addCompanyMessage(int reportId, String messageText) async {
    if (!isConfigured) return false;
    try {
      // 取得現有 conversation
      final existing = await client
          .from('reports')
          .select('conversation')
          .eq('id', reportId)
          .single();

      final conv = _decodeConversation(existing['conversation']);

      // 添加新訊息
      conv.add({
        'sender': 'company',
        'text': messageText,
        'image': null,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await client.from('reports').update({
        'company_notes': messageText, // 向後兼容（最後一條公司訊息）
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

  List<dynamic> _decodeConversation(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return List<dynamic>.from(raw);
    if (raw is String) {
      if (raw.isEmpty) return [];
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return List<dynamic>.from(decoded);
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  /// 清除未讀標記（工人端查看後調用）
  Future<void> clearUnreadCompany(int reportId) async {
    if (!isConfigured) return;
    try {
      await client.from('reports').update({
        'has_unread_company': false,
      }).eq('id', reportId);
    } catch (e) {
      debugPrint('❌ clearUnreadCompany 失敗: $e');
    }
  }

  /// 將 Supabase 原始 Map 轉換為 ReportModel
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

  /// 刪除雲端報告（by local_id）
  Future<bool> deleteReport(int localId) async {
    if (!isConfigured) return false;
    try {
      await client.from('reports').delete().eq('local_id', localId);
      debugPrint('✅ Supabase: 已刪除報告 local_id=$localId');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase deleteReport 失敗: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // INSPECTION SESSIONS — 巡檢會話雲端同步
  // ══════════════════════════════════════════════════════════

  /// 上傳或更新巡檢會話（以 session_id 為唯一鍵）
  Future<bool> upsertInspectionSession(Map<String, dynamic> sessionJson) async {
    if (!isConfigured) return false;
    try {
      final payload = Map<String, dynamic>.from(sessionJson);
      final sessionId = payload['id']?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        debugPrint('❌ upsertInspectionSession: 缺少 session id');
        return false;
      }

      final createdAt = payload['createdAt']?.toString();
      final updatedAt = payload['updatedAt']?.toString();

      Map<String, dynamic> mergedPayload = Map<String, dynamic>.from(payload);
      String? finalFloorPlanPath = payload['floorPlanPath']?.toString();

      try {
        final existing = await client
            .from('inspection_sessions')
            .select('floor_plan_path, payload')
            .eq('session_id', sessionId)
            .maybeSingle();

        if (existing != null) {
          final existingRow = Map<String, dynamic>.from(existing);
          final existingPayload = Map<String, dynamic>.from(
            existingRow['payload'] as Map<String, dynamic>? ?? {},
          );

          mergedPayload = {
            ...existingPayload,
            ...payload,
          };

          final existingFloorPlanPath = (existingRow['floor_plan_path'] ??
                  existingPayload['floorPlanPath'])
              ?.toString();

          // If incoming payload only has a local device path, keep cloud-usable path.
          if (_isLikelyLocalPath(finalFloorPlanPath) &&
              !_isLikelyLocalPath(existingFloorPlanPath) &&
              (existingFloorPlanPath?.isNotEmpty ?? false)) {
            finalFloorPlanPath = existingFloorPlanPath;
          }

          final incomingUrl =
              (payload['floor_plan_url'] ?? payload['floorPlanUrl'])
                  ?.toString();
          final existingUrl = (existingPayload['floor_plan_url'] ??
                  existingPayload['floorPlanUrl'])
              ?.toString();
          if ((incomingUrl == null || incomingUrl.isEmpty) &&
              (existingUrl != null && existingUrl.isNotEmpty)) {
            mergedPayload['floor_plan_url'] =
                existingPayload['floor_plan_url'] ?? existingUrl;
            mergedPayload['floorPlanUrl'] =
                existingPayload['floorPlanUrl'] ?? existingUrl;
          }

          final incomingBase64 =
              (payload['floor_plan_base64'] ?? payload['floorPlanBase64'])
                  ?.toString();
          final existingBase64 = (existingPayload['floor_plan_base64'] ??
                  existingPayload['floorPlanBase64'])
              ?.toString();
          if ((incomingBase64 == null || incomingBase64.isEmpty) &&
              (existingBase64 != null && existingBase64.isNotEmpty)) {
            mergedPayload['floor_plan_base64'] =
                existingPayload['floor_plan_base64'] ?? existingBase64;
            mergedPayload['floorPlanBase64'] =
                existingPayload['floorPlanBase64'] ?? existingBase64;
          }
        }
      } catch (mergeError) {
        debugPrint('⚠️ upsertInspectionSession merge fallback: $mergeError');
      }

      if (finalFloorPlanPath != null && finalFloorPlanPath.isNotEmpty) {
        mergedPayload['floorPlanPath'] = finalFloorPlanPath;
      }

      await client.from('inspection_sessions').upsert({
        'session_id': sessionId,
        'name': payload['name'],
        'project_id': payload['projectId'],
        'floor': payload['floor'],
        'floor_plan_path': finalFloorPlanPath,
        'status': payload['status'],
        'payload': mergedPayload,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
        'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      }, onConflict: 'session_id');

      return true;
    } catch (e) {
      debugPrint('❌ upsertInspectionSession 失敗: $e');
      return false;
    }
  }

  bool _isLikelyLocalPath(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    final value = raw.trim();
    final lower = value.toLowerCase();
    if (lower.startsWith('file://')) return true;
    if (lower.startsWith('/data/')) return true;
    if (lower.startsWith('/storage/')) return true;
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value)) return true;
    return false;
  }

  /// 讀取所有巡檢會話（依 updated_at 由新到舊）
  Future<List<Map<String, dynamic>>> fetchInspectionSessions() async {
    if (!isConfigured) return [];
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

  /// 刪除單一巡檢會話
  Future<bool> deleteInspectionSession(String sessionId) async {
    if (!isConfigured) return false;
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

  // ══════════════════════════════════════════════════════════
  // FLOOR PLANS — 樓層圖雲端儲存
  // ══════════════════════════════════════════════════════════

  /// 上傳樓層圖到 Supabase Storage，返回公開 URL
  ///
  /// [buildingId] 建物識別碼（例如 "building_A"）
  /// [floor]      樓層號碼（例如 1、2、3）
  /// [imageBytes] 圖片原始位元組（PNG/JPG）
  /// [extension]  副檔名，預設 'png'
  Future<String?> uploadFloorPlan({
    required String buildingId,
    required int floor,
    required Uint8List imageBytes,
    String extension = 'png',
  }) async {
    if (!isConfigured) return null;
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

  /// 取得已上傳樓層圖的公開 URL（不重新上傳）
  String? getFloorPlanUrl(String buildingId, int floor,
      [String extension = 'png']) {
    if (!isConfigured) return null;
    final path = 'buildings/$buildingId/floor_$floor.$extension';
    return client.storage.from('floor-plans').getPublicUrl(path);
  }

  /// 下載樓層圖位元組
  Future<Uint8List?> downloadFloorPlan(String buildingId, int floor,
      [String extension = 'png']) async {
    if (!isConfigured) return null;
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

  /// 列出指定建物的所有樓層圖
  Future<List<FileObject>> listFloorPlans(String buildingId) async {
    if (!isConfigured) return [];
    try {
      return await client.storage
          .from('floor-plans')
          .list(path: 'buildings/$buildingId');
    } catch (e) {
      debugPrint('❌ Supabase listFloorPlans 失敗: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════

  /// 上傳圖片供 AI 分析用，返回 Supabase 公開 URL（不依附報告 ID）
  Future<String?> uploadImageForAnalysis(String imageBase64) async {
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
