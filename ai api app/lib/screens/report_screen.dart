import 'package:flutter/material.dart';

import 'package:ai_api_classifier/l10n/app_i18n.dart';
import 'package:ai_api_classifier/models/analysis_record.dart';
import 'package:ai_api_classifier/services/analysis_record_storage.dart';
import 'package:ai_api_classifier/services/defect_classifier_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.language});

  static const String routeName = '/report';
  final AppLanguage language;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final AnalysisRecordStorage _storage = AnalysisRecordStorage();
  bool _loading = true;
  List<AnalysisRecord> _records = <AnalysisRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await _storage.loadRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _deleteRecord(AnalysisRecord record) async {
    await _storage.deleteRecord(record.id);
    if (!mounted) return;
    setState(() {
      _records.removeWhere((r) => r.id == record.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n(widget.language);
    final total = _records.length;
    final counts = <String, int>{
      for (final label in DefectClassifierService.supportedLabels) label: 0,
    };

    for (final r in _records) {
      counts[r.result] = (counts[r.result] ?? 0) + 1;
    }

    final unknownCount = counts['Unknown'] ?? 0;
    final otherCount = counts['Other'] ?? 0;
    final unknownRatio = total == 0 ? 0 : (unknownCount * 100 / total);
    final otherRatio = total == 0 ? 0 : (otherCount * 100 / total);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.report),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i18n.totalRecords}: $total',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DefectClassifierService.supportedLabels
                            .map(
                              (label) => Chip(
                                label: Text('$label: ${counts[label] ?? 0}'),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(i18n.unknownRatio(unknownRatio.toStringAsFixed(1))),
                      Text(i18n.otherRatio(otherRatio.toStringAsFixed(1))),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _records.isEmpty
                      ? Center(child: Text(i18n.noRecords))
                      : ListView.separated(
                          itemCount: _records.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = _records[i];
                            final subtitle = r.hasError
                                ? i18n.resultErrorText(
                                    r.result,
                                    r.error ?? 'Unknown error',
                                  )
                                : i18n.resultText(r.result);
                            return ListTile(
                              title: Text(
                                r.imageName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '$subtitle\n${r.createdAt.toLocal()}',
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                onPressed: () => _deleteRecord(r),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: i18n.deleteRecord,
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
