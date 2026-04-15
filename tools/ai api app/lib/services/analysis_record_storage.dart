import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_api_classifier/models/analysis_record.dart';

class AnalysisRecordStorage {
  static const String _storageKey = 'analysis_records_v1';

  Future<List<AnalysisRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <AnalysisRecord>[];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => AnalysisRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRecords(List<AnalysisRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(records.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> addRecord(AnalysisRecord record) async {
    final list = await loadRecords();
    list.insert(0, record);
    await saveRecords(list);
  }

  Future<void> deleteRecord(String id) async {
    final list = await loadRecords();
    list.removeWhere((r) => r.id == id);
    await saveRecords(list);
  }
}
