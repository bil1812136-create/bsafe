import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bsafe_app/features/defect_reporting/data/models/report_model.dart';
import 'package:bsafe_app/features/defect_reporting/presentation/providers/report_provider.dart';
import 'package:bsafe_app/features/defect_reporting/presentation/pages/report_detail_page.dart';
import 'package:bsafe_app/core/providers/navigation_provider.dart';
import 'package:bsafe_app/core/providers/language_provider.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';
import 'package:bsafe_app/shared/widgets/report_detail_card.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _searchQuery = '';
  bool _isSyncing = false;

  List<ReportModel> _getFilteredReports(
    List<ReportModel> reports,
    String filterRisk,
    String filterStatus,
  ) {
    return reports.where((report) {
      if (filterRisk != 'all' && report.riskLevel != filterRisk) return false;
      if (filterStatus != 'all' && report.status != filterStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return report.title.toLowerCase().contains(q) ||
            report.description.toLowerCase().contains(q) ||
            (report.location?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  Future<void> _syncToCloud() async {
    setState(() => _isSyncing = true);
    final count =
        await ref.read(reportNotifierProvider.notifier).syncAllToCloud();
    final language = ref.read(languageNotifierProvider);
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.cloud_done, color: Colors.white),
          const SizedBox(width: 8),
          Text(count > 0
              ? '${language.t('synced_success')} $count ${language.t('synced_count')}'
              : language.t('all_updated')),
        ]),
        backgroundColor: count > 0 ? Colors.green : Colors.grey.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageNotifierProvider);
    final reportState = ref.watch(reportNotifierProvider);
    final navigation = ref.watch(navigationNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(language.t('history')),
        actions: [
          Builder(builder: (context) {
            final unsyncedCount =
                reportState.reports.where((r) => !r.synced).length;
            return Stack(alignment: Alignment.center, children: [
              IconButton(
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload),
                tooltip: language.t('sync_to_cloud'),
                onPressed: _isSyncing ? null : _syncToCloud,
              ),
              if (unsyncedCount > 0 && !_isSyncing)
                Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Center(
                          child: Text('$unsyncedCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold))),
                    )),
            ]);
          }),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: language.t('search_report'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''))
                    : null,
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Builder(builder: (context) {
            final filterRisk = navigation.historyFilterRisk;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _FilterChip(
                    label: language.t('all'),
                    isSelected: filterRisk == 'all',
                    onSelected: () => ref
                        .read(navigationNotifierProvider.notifier)
                        .setHistoryFilters(risk: 'all')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: language.t('high_risk'),
                    isSelected: filterRisk == 'high',
                    color: AppTheme.riskHigh,
                    onSelected: () => ref
                        .read(navigationNotifierProvider.notifier)
                        .setHistoryFilters(risk: 'high')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: language.t('medium_risk'),
                    isSelected: filterRisk == 'medium',
                    color: AppTheme.riskMedium,
                    onSelected: () => ref
                        .read(navigationNotifierProvider.notifier)
                        .setHistoryFilters(risk: 'medium')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: language.t('low_risk'),
                    isSelected: filterRisk == 'low',
                    color: AppTheme.riskLow,
                    onSelected: () => ref
                        .read(navigationNotifierProvider.notifier)
                        .setHistoryFilters(risk: 'low')),
              ]),
            );
          }),
          const SizedBox(height: 8),
          Expanded(
            child: Builder(
              builder: (context) {
                if (reportState.isLoading && reportState.reports.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filtered = _getFilteredReports(
                    reportState.reports,
                    navigation.historyFilterRisk,
                    navigation.historyFilterStatus);
                if (filtered.isEmpty) {
                  return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ||
                                  navigation.historyFilterRisk != 'all'
                              ? language.t('no_matching_report')
                              : language.t('no_report_yet'),
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ]));
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(reportNotifierProvider.notifier).loadReports(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final report = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReportDetailCard(
                          report: report,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ReportDetailPage(report: report))),
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onSelected;

  const _FilterChip(
      {required this.label,
      required this.isSelected,
      this.color,
      required this.onSelected});

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
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
