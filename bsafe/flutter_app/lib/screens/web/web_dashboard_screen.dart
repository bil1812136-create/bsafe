import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:bsafe_app/screens/web/web_report_detail_screen.dart';
import 'package:intl/intl.dart';

/// 公司管理後台 — 主 Dashboard
class WebDashboardScreen extends StatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String? _error;
  String _filterRiskLevel = 'all';
  String _filterStatus = 'all';
  Timer? _refreshTimer;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadReports();
    // 每 15 秒自動刷新（接收手機端新報告）
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadReports(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReports({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      var query = _supabase.from('reports').select();

      if (_filterRiskLevel != 'all') {
        query = query.eq('risk_level', _filterRiskLevel);
      }
      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '載入失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Row(
        children: [
          // ── 左側邊欄 ──
          _buildSidebar(),

          // ── 主內容區 ──
          Expanded(
            child: Column(
              children: [
                _buildTopBar(screenWidth),
                _buildStatsRow(),
                _buildFilterBar(),
                Expanded(child: _buildReportTable()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════ 側邊欄 ═══════════

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: AppTheme.primaryDark,
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Row(
              children: [
                Icon(Icons.shield, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  'B-SAFE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '公司管理後台',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Nav items
          _sidebarItem(Icons.dashboard, '報告總覽', true),
          _sidebarItem(Icons.analytics, '統計分析', false),
          _sidebarItem(Icons.map, '樓層圖管理', false),
          _sidebarItem(Icons.settings, '設定', false),
          const Spacer(),
          // Connection status
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Supabase 已連接',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading:
            Icon(icon, color: active ? Colors.white : Colors.white54, size: 22),
        title: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        dense: true,
        onTap: () {},
      ),
    );
  }

  // ═══════════ 頂部欄 ═══════════

  Widget _buildTopBar(double screenWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      color: Colors.white,
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '報告總覽',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '手機端上報的 AI 分析報告會自動同步到此頁面',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          // 手動刷新
          OutlinedButton.icon(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('刷新'),
          ),
          const SizedBox(width: 12),
          Text(
            '共 ${_reports.length} 筆報告',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════ 統計卡 ═══════════

  Widget _buildStatsRow() {
    final total = _reports.length;
    final high = _reports.where((r) => r['risk_level'] == 'high').length;
    final medium = _reports.where((r) => r['risk_level'] == 'medium').length;
    final low = _reports.where((r) => r['risk_level'] == 'low').length;
    final pending = _reports.where((r) => r['status'] == 'pending').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          _statCard('全部報告', '$total', AppTheme.primaryColor, Icons.description),
          const SizedBox(width: 16),
          _statCard('高風險', '$high', AppTheme.riskHigh, Icons.warning),
          const SizedBox(width: 16),
          _statCard('中風險', '$medium', AppTheme.riskMedium, Icons.info),
          const SizedBox(width: 16),
          _statCard('低風險', '$low', AppTheme.riskLow, Icons.check_circle),
          const SizedBox(width: 16),
          _statCard('待處理', '$pending', Colors.purple, Icons.pending_actions),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════ 篩選欄 ═══════════

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const Text('篩選:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          _filterChip('全部', 'all', _filterRiskLevel, (v) {
            setState(() => _filterRiskLevel = v);
            _loadReports();
          }),
          _filterChip('高風險', 'high', _filterRiskLevel, (v) {
            setState(() => _filterRiskLevel = v);
            _loadReports();
          }),
          _filterChip('中風險', 'medium', _filterRiskLevel, (v) {
            setState(() => _filterRiskLevel = v);
            _loadReports();
          }),
          _filterChip('低風險', 'low', _filterRiskLevel, (v) {
            setState(() => _filterRiskLevel = v);
            _loadReports();
          }),
          const SizedBox(width: 24),
          const Text('狀態:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          _filterChip('全部', 'all', _filterStatus, (v) {
            setState(() => _filterStatus = v);
            _loadReports();
          }),
          _filterChip('待處理', 'pending', _filterStatus, (v) {
            setState(() => _filterStatus = v);
            _loadReports();
          }),
          _filterChip('已解決', 'resolved', _filterStatus, (v) {
            setState(() => _filterStatus = v);
            _loadReports();
          }),
        ],
      ),
    );
  }

  Widget _filterChip(
      String label, String value, String current, ValueChanged<String> onTap) {
    final active = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(value),
        selectedColor: AppTheme.primaryColor.withOpacity(0.15),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  // ═══════════ 報告表格 ═══════════

  Widget _buildReportTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadReports, child: const Text('重試')),
          ],
        ),
      );
    }
    if (_reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              '尚無報告',
              style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              '手機端上報後會自動同步到此頁面（每15秒刷新一次）',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppTheme.primaryColor.withOpacity(0.05),
              ),
              columnSpacing: 24,
              columns: const [
                DataColumn(
                    label: Text('#',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('標題',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('類別',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('風險等級',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('風險分數',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('狀態',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('日期',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('操作',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _reports.asMap().entries.map((entry) {
                final idx = entry.key;
                final report = entry.value;
                return _buildRow(idx, report);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(int index, Map<String, dynamic> report) {
    final riskLevel = report['risk_level'] ?? 'low';
    final riskColor = AppTheme.getRiskColor(riskLevel);
    final status = report['status'] ?? 'pending';
    final createdAt = report['created_at'] != null
        ? DateFormat('yyyy/MM/dd HH:mm')
            .format(DateTime.parse(report['created_at']).toLocal())
        : '-';
    final category = _categoryLabel(report['category'] ?? '');

    return DataRow(
      cells: [
        DataCell(Text('${index + 1}',
            style: const TextStyle(color: AppTheme.textSecondary))),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              report['title'] ?? '無標題',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        DataCell(Text(category)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              AppTheme.getRiskLabel(riskLevel),
              style: TextStyle(
                color: riskColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(Text(
          '${report['risk_score'] ?? 0}',
          style: TextStyle(fontWeight: FontWeight.bold, color: riskColor),
        )),
        DataCell(_statusBadge(status)),
        DataCell(Text(
          createdAt,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        )),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                color: AppTheme.primaryColor,
                tooltip: '查看 / 編輯',
                onPressed: () => _openDetail(report),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.red.shade300,
                tooltip: '刪除',
                onPressed: () => _confirmDelete(report),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'resolved':
        color = Colors.green;
        label = '已解決';
        break;
      case 'in_progress':
        color = Colors.orange;
        label = '處理中';
        break;
      default:
        color = Colors.grey;
        label = '待處理';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  String _categoryLabel(String category) {
    const map = {
      'structural': '結構性問題',
      'exterior': '外牆問題',
      'public_area': '公共區域',
      'electrical': '電氣問題',
      'plumbing': '水管問題',
      'other': '其他',
    };
    return map[category] ?? category;
  }

  void _openDetail(Map<String, dynamic> report) async {
    final edited = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WebReportDetailScreen(report: report),
      ),
    );
    if (edited == true) {
      _loadReports();
    }
  }

  void _confirmDelete(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除報告「${report['title']}」嗎？此操作無法復原。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _supabase.from('reports').delete().eq('id', report['id']);
              _loadReports();
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}
