import 'dart:convert';
import 'dart:typed_data';
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
///    -- AI 分析報告表
///    CREATE TABLE reports (
///      id            BIGSERIAL PRIMARY KEY,
///      local_id      INTEGER,
///      title         TEXT NOT NULL,
///      description   TEXT NOT NULL,
///      category      TEXT NOT NULL,
///      severity      TEXT NOT NULL,
///      risk_level    TEXT DEFAULT 'low',
///      risk_score    INTEGER DEFAULT 0,
///      is_urgent     BOOLEAN DEFAULT FALSE,
///      status        TEXT DEFAULT 'pending',
///      image_url     TEXT,
///      location      TEXT,
///      latitude      DOUBLE PRECISION,
///      longitude     DOUBLE PRECISION,
///      ai_analysis   TEXT,
///      created_at    TIMESTAMPTZ DEFAULT NOW(),
///      updated_at    TIMESTAMPTZ DEFAULT NOW(),
///      UNIQUE(local_id)
///    );
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
  static const String supabaseUrl = 'https://adtahhkhyuyqipkulwwp.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFkdGFoaGtoeXV5cWlwa3Vsd3dwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2OTE0MTAsImV4cCI6MjA4ODI2NzQxMH0.HpCdD2BRnhnuNdqavWfJAaePHfYLFEt0nRafmEF2Ido';
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
      // 先上傳圖片到 Storage，取得公開 URL
      String? imageUrl;
      if (report.imageBase64 != null && report.imageBase64!.isNotEmpty) {
        imageUrl = await _uploadReportImage(
          report.imageBase64!,
          report.id?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
        );
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
        'location': report.location,
        'latitude': report.latitude,
        'longitude': report.longitude,
        'ai_analysis': report.aiAnalysis,
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
