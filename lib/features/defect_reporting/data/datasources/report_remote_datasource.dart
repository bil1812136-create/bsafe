import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/core/config/app_config.dart';
import 'package:bsafe_app/features/defect_reporting/data/models/report_model.dart';
import 'package:bsafe_app/features/defect_reporting/domain/entities/report.dart';

/// Supabase-backed remote data-source for reports.
/// Only this class knows about Supabase — all other layers are decoupled.
class ReportRemoteDataSource {
  static final ReportRemoteDataSource instance = ReportRemoteDataSource._init();
  ReportRemoteDataSource._init();

  SupabaseClient get _client => Supabase.instance.client;

  bool get _isReady => AppConfig.isSupabaseConfigured && _isInitialized;

  bool get _isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Fetch ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAll() async {
    if (!_isReady) return [];
    try {
      final response = await _client
          .from('reports')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ ReportRemoteDataSource.fetchAll: $e');
      return [];
    }
  }

  // ── Create ──────────────────────────────────────────────

  Future<ReportModel?> create(Report report, {String? imageBase64}) async {
    if (!_isReady) return null;
    try {
      String? imageUrl;
      String? fallbackBase64;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        imageUrl = await _uploadImage(
          imageBase64,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
        if (imageUrl == null) {
          fallbackBase64 = imageBase64;
          debugPrint('⚠️ Storage 上傳失敗，改以 base64 存入 DB');
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
          await _client.from('reports').insert(data).select().single();
      debugPrint('✅ Report created: id=${response['id']}');
      return mapToModel(response);
    } catch (e) {
      debugPrint('❌ ReportRemoteDataSource.create: $e');
      return null;
    }
  }

  // ── Update status ───────────────────────────────────────

  Future<bool> updateStatus(int id, String newStatus) async {
    if (!_isReady) return false;
    try {
      await _client.from('reports').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ ReportRemoteDataSource.updateStatus: $e');
      return false;
    }
  }

  // ── Worker response ─────────────────────────────────────

  Future<bool> submitWorkerResponse(
      int reportId, String text, String? imageBase64) async {
    if (!_isReady) return false;
    try {
      String? responseImageUrl;
      String? fallbackBase64;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        responseImageUrl = await _uploadImage(
          imageBase64,
          'response_${reportId}_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (responseImageUrl == null) fallbackBase64 = imageBase64;
      }

      final existing = await _client
          .from('reports')
          .select('conversation')
          .eq('id', reportId)
          .single();

      final conv = _parseConversation(existing['conversation']);
      conv.add({
        'sender': 'worker',
        'text': text,
        'image': responseImageUrl ?? fallbackBase64,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _client.from('reports').update({
        'worker_response': text,
        'worker_response_image': responseImageUrl ?? fallbackBase64,
        'conversation': jsonEncode(conv),
        'has_unread_company': false,
        'status': 'in_progress',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);

      return true;
    } catch (e) {
      debugPrint('❌ ReportRemoteDataSource.submitWorkerResponse: $e');
      return false;
    }
  }

  // ── Company message ─────────────────────────────────────

  Future<bool> addCompanyMessage(int reportId, String message) async {
    if (!_isReady) return false;
    try {
      final existing = await _client
          .from('reports')
          .select('conversation')
          .eq('id', reportId)
          .single();

      final conv = _parseConversation(existing['conversation']);
      conv.add({
        'sender': 'company',
        'text': message,
        'image': null,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _client.from('reports').update({
        'company_notes': message,
        'conversation': jsonEncode(conv),
        'has_unread_company': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);

      return true;
    } catch (e) {
      debugPrint('❌ ReportRemoteDataSource.addCompanyMessage: $e');
      return false;
    }
  }

  // ── Clear unread ────────────────────────────────────────

  Future<void> clearUnreadCompany(int reportId) async {
    if (!_isReady) return;
    try {
      await _client.from('reports').update({
        'has_unread_company': false,
      }).eq('id', reportId);
    } catch (e) {
      debugPrint('❌ ReportRemoteDataSource.clearUnreadCompany: $e');
    }
  }

  // ── Helpers ─────────────────────────────────────────────

  Future<String?> _uploadImage(String base64, String name) async {
    try {
      final bytes = base64Decode(base64);
      final path =
          'reports/${name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from(AppConfig.reportImagesBucket).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      return _client.storage
          .from(AppConfig.reportImagesBucket)
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('⚠️ Image upload failed: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> _parseConversation(dynamic raw) {
    if (raw == null) return [];
    try {
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        return decoded is List ? List<Map<String, dynamic>>.from(decoded) : [];
      }
    } catch (_) {}
    return [];
  }

  static ReportModel mapToModel(Map<String, dynamic> data) => ReportModel(
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
        conversation: ReportModel.fromJson({
          ...data,
          'id': data['id'],
        }).conversation,
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
