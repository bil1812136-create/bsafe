import 'package:flutter/foundation.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/services/supabase_service.dart';

/// 實時監聽 Supabase 報告數據變化的服務
/// 用於在 webapp 或手機 app 間自動同步對話和狀態更新
///
/// ⚠️ 注意：使用基於輪詢的刷新方式，而非 Realtime API
/// （Realtime API 配置複雜，此方法更穩定且易於維護）
class RealtimeService {
  static final RealtimeService instance = RealtimeService._init();
  RealtimeService._init();

  final Map<int, List<Function(ReportModel)>> _listeners = {};
  final Map<int, ReportModel?> _cachedReports = {}; // 緩存上次的報告數據，用於對比
  final Map<int, String> _conversationHashes =
      {}; // 僅緩存 conversation 的 hash 值（極輕量）

  /// 訂閱特定報告的實時更新
  /// 使用定時刷新機制（每2秒檢查一次）
  Future<void> subscribeToReport(
      int reportId, Function(ReportModel) onUpdate) async {
    if (!SupabaseService.isConfigured) return;

    // 保存監聽器
    if (!_listeners.containsKey(reportId)) {
      _listeners[reportId] = [];
    }
    _listeners[reportId]!.add(onUpdate);

    debugPrint('👁️ Realtime: 開始監聽報告 #$reportId');

    // 啟動定時輪詢
    _startPolling(reportId);
  }

  /// 啟動定時輪詢機制
  Future<void> _startPolling(int reportId) async {
    // 防止重複啟動
    if (_pollingTimers.containsKey(reportId)) {
      return;
    }
    _pollingTimers[reportId] = true;

    // 計時器間隔：5秒檢查一次（避免過度輪詢導致閃爍）
    Future<void> poll() async {
      try {
        // 從 Supabase 只拉取 conversation 字段（減少網路傳輸和計算）
        final lightResponse = await SupabaseService.instance.client
            .from('reports')
            .select('conversation')
            .eq('id', reportId)
            .single();

        if (lightResponse.isNotEmpty) {
          final conversation = lightResponse['conversation']?.toString() ?? '';
          final currentHash = conversation.hashCode.toString();

          // 極輕量級的 hash 對比：只有當 conversation 內容真的改變時，才拉取完整數據
          final lastHash = _conversationHashes[reportId];
          if (lastHash == null || lastHash != currentHash) {
            debugPrint(
                '📨 對話內容有變化（hash: $lastHash → $currentHash），拉取完整數據並更新UI');
            _conversationHashes[reportId] = currentHash;

            // 只有確認有變化後，才拉取完整報告數據（避免不必要的大數據傳輸）
            try {
              final fullResponse = await SupabaseService.instance.client
                  .from('reports')
                  .select()
                  .eq('id', reportId)
                  .single();

              if (fullResponse.isNotEmpty) {
                final updatedReport =
                    SupabaseService.mapToReportModel(fullResponse);
                _cachedReports[reportId] = updatedReport;

                // 觸發所有監聽該報告的回調
                final callbacks = _listeners[reportId] ?? [];
                for (final callback in callbacks) {
                  try {
                    callback(updatedReport);
                  } catch (e) {
                    debugPrint('❌ 回調執行失敗: $e');
                  }
                }
              }
            } catch (e) {
              debugPrint('⚠️ 拉取完整數據失敗: $e');
            }
          } else {
            debugPrint('✓ 對話無變化（hash: $currentHash），跳過網路查詢');
          }
        }
      } catch (e) {
        debugPrint('⚠️ 輪詢刷新失敗 (報告 #$reportId): $e');
        // 輪詢失敗不中斷，繼續嘗試
      }
    }

    // 立即執行一次
    await poll();

    // 定期輪詢：每2秒
    Future.doWhile(() async {
      // 檢查是否還有監聽器
      if (!_listeners.containsKey(reportId) || _listeners[reportId]!.isEmpty) {
        _pollingTimers.remove(reportId);
        _cachedReports.remove(reportId);
        debugPrint('✋ 停止輪詢報告 #$reportId（無監聽器）');
        return false;
      }

      await Future.delayed(const Duration(seconds: 5));
      await poll();
      return true;
    });
  }

  final Map<int, bool> _pollingTimers = {};

  /// 取消訂閱特定報告
  Future<void> unsubscribeFromReport(int reportId) async {
    _listeners.remove(reportId);
    _pollingTimers.remove(reportId);
    _cachedReports.remove(reportId);
    _conversationHashes.remove(reportId);
    debugPrint('✅ 已取消訂閱報告 #$reportId');
  }

  /// 取消訂閱所有報告
  Future<void> unsubscribeAll() async {
    for (final reportId in _listeners.keys.toList()) {
      await unsubscribeFromReport(reportId);
    }
    _listeners.clear();
    _pollingTimers.clear();
    _cachedReports.clear();
    _conversationHashes.clear();
    debugPrint('✅ 已取消所有訂閱');
  }

  /// 獲取訂閱狀態
  bool isSubscribedTo(int reportId) {
    return _listeners.containsKey(reportId) && _listeners[reportId]!.isNotEmpty;
  }
}
