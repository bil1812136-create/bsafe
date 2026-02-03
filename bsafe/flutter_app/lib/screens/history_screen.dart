import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:bsafe_app/widgets/report_detail_card.dart';
import 'package:bsafe_app/screens/report_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filterRisk = 'all';
  String _filterStatus = 'all';
  String _searchQuery = '';

  List<ReportModel> _getFilteredReports(List<ReportModel> reports) {
    return reports.where((report) {
      // Filter by risk level
      if (_filterRisk != 'all' && report.riskLevel != _filterRisk) {
        return false;
      }

      // Filter by status
      if (_filterStatus != 'all' && report.status != _filterStatus) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return report.title.toLowerCase().contains(query) ||
            report.description.toLowerCase().contains(query) ||
            (report.location?.toLowerCase().contains(query) ?? false);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索報告...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: '全部',
                  isSelected: _filterRisk == 'all',
                  onSelected: () => setState(() => _filterRisk = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '高風險',
                  isSelected: _filterRisk == 'high',
                  color: AppTheme.riskHigh,
                  onSelected: () => setState(() => _filterRisk = 'high'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '中風險',
                  isSelected: _filterRisk == 'medium',
                  color: AppTheme.riskMedium,
                  onSelected: () => setState(() => _filterRisk = 'medium'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '低風險',
                  isSelected: _filterRisk == 'low',
                  color: AppTheme.riskLow,
                  onSelected: () => setState(() => _filterRisk = 'low'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Reports List
          Expanded(
            child: Consumer<ReportProvider>(
              builder: (context, reportProvider, _) {
                if (reportProvider.isLoading &&
                    reportProvider.reports.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredReports =
                    _getFilteredReports(reportProvider.reports);

                if (filteredReports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _filterRisk != 'all'
                              ? '沒有符合條件的報告'
                              : '暫無報告記錄',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => reportProvider.loadReports(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredReports.length,
                    itemBuilder: (context, index) {
                      final report = filteredReports[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReportDetailCard(
                          report: report,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReportDetailScreen(report: report),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '篩選條件',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '狀態',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('全部'),
                      selected: _filterStatus == 'all',
                      onSelected: (_) {
                        setModalState(() => _filterStatus = 'all');
                        setState(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('待處理'),
                      selected: _filterStatus == 'pending',
                      onSelected: (_) {
                        setModalState(() => _filterStatus = 'pending');
                        setState(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('處理中'),
                      selected: _filterStatus == 'in_progress',
                      onSelected: (_) {
                        setModalState(() => _filterStatus = 'in_progress');
                        setState(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('已解決'),
                      selected: _filterStatus == 'resolved',
                      onSelected: (_) {
                        setModalState(() => _filterStatus = 'resolved');
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('確定'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppTheme.primaryColor)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
