import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:ai_api_classifier/models/analysis_record.dart';
import 'package:ai_api_classifier/screens/report_screen.dart';
import 'package:ai_api_classifier/services/analysis_record_storage.dart';
import 'package:ai_api_classifier/services/defect_classifier_service.dart';
import 'package:ai_api_classifier/l10n/app_i18n.dart';
import 'package:ai_api_classifier/utils/picked_image_data.dart';
import 'package:ai_api_classifier/utils/folder_picker_stub.dart'
    if (dart.library.io) 'package:ai_api_classifier/utils/folder_picker_io.dart';

class AiApiBatchScreen extends StatefulWidget {
  const AiApiBatchScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<AiApiBatchScreen> createState() => _AiApiBatchScreenState();
}

class _AiApiBatchScreenState extends State<AiApiBatchScreen> {
  final DefectClassifierService _service = DefectClassifierService();
  final AnalysisRecordStorage _recordStorage = AnalysisRecordStorage();
  final List<_ImageTask> _tasks = <_ImageTask>[];

  bool _isRunning = false;
  int _doneCount = 0;

  Future<void> _pickImages() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
      withReadStream: false,
    );
    if (picked == null || picked.files.isEmpty) return;

    final selected = picked.files
        .where((f) => f.bytes != null && f.bytes!.isNotEmpty)
        .take(100)
        .map(
          (f) => _ImageTask(
            name: f.name,
            bytes: f.bytes!,
          ),
        )
        .toList();

    setState(() {
      _tasks
        ..clear()
        ..addAll(selected);
      _doneCount = 0;
    });

    if (picked.files.length > 100 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多只會處理前 100 張圖片')),
      );
    }
  }

  Future<void> _pickFolder() async {
    final picked = await pickImagesFromFolder();
    if (picked.isEmpty) {
      if (!kIsWeb && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('資料夾沒有可用圖片，或你取消了選擇')),
        );
      }
      if (kIsWeb && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web 不支援資料夾模式，請改用多選圖片')),
        );
      }
      return;
    }

    final loaded = picked
        .take(100)
        .map(
          (PickedImageData p) => _ImageTask(name: p.name, bytes: p.bytes),
        )
        .toList();

    if (loaded.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法讀取資料夾內圖片，請改用多選圖片模式')),
        );
      }
      return;
    }

    setState(() {
      _tasks
        ..clear()
        ..addAll(loaded);
      _doneCount = 0;
    });

    if (picked.length > 100 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多只會處理前 100 張圖片')),
      );
    }
  }

  Future<void> _analyzeAll() async {
    if (_tasks.isEmpty || _isRunning) return;

    setState(() {
      _isRunning = true;
      _doneCount = 0;
      for (final t in _tasks) {
        t.status = _TaskStatus.pending;
        t.label = null;
        t.error = null;
      }
    });

    for (final t in _tasks) {
      if (!mounted) return;
      setState(() {
        t.status = _TaskStatus.running;
      });

      try {
        final label = await _service.classifyDefect(t.bytes);
        await _recordStorage.addRecord(
          AnalysisRecord(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            imageName: t.name,
            result: label,
            createdAt: DateTime.now(),
          ),
        );
        if (!mounted) return;
        setState(() {
          t.status = _TaskStatus.done;
          t.label = label;
          _doneCount += 1;
        });
      } catch (e) {
        await _recordStorage.addRecord(
          AnalysisRecord(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            imageName: t.name,
            result: 'Unknown',
            createdAt: DateTime.now(),
            error: e.toString(),
          ),
        );
        if (!mounted) return;
        setState(() {
          t.status = _TaskStatus.error;
          t.error = e.toString();
          _doneCount += 1;
        });
      }

      // 延遲 500ms 避免 API 限流 (429)
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _clear() {
    if (_isRunning) return;
    setState(() {
      _tasks.clear();
      _doneCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tasks.isEmpty ? 0.0 : _doneCount / _tasks.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI API Defect Classifier'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(ReportScreen.routeName);
            },
            icon: const Icon(Icons.analytics_outlined),
            tooltip: '統計報表',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _pickImages,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('選擇 1-100 張圖片'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRunning ? null : _pickFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('選擇資料夾（桌面）'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      (_tasks.isEmpty || _isRunning) ? null : _analyzeAll,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('開始分析'),
                ),
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('進度: $_doneCount / ${_tasks.length}'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _tasks.isEmpty
                  ? const Center(
                      child: Text('先選圖片或資料夾，再按開始分析'),
                    )
                  : ListView.separated(
                      itemCount: _tasks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final t = _tasks[i];
                        return ListTile(
                          leading: SizedBox(
                            width: 44,
                            height: 44,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(t.bytes, fit: BoxFit.cover),
                            ),
                          ),
                          title: Text(
                            t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(_statusText(t)),
                          trailing: _statusIcon(t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(_ImageTask t) {
    switch (t.status) {
      case _TaskStatus.pending:
        return '等待中';
      case _TaskStatus.running:
        return '分析中...';
      case _TaskStatus.done:
        return 'Defect: ${t.label ?? 'Other'}';
      case _TaskStatus.error:
        return '錯誤: ${t.error ?? 'Unknown error'}';
    }
  }

  Widget _statusIcon(_ImageTask t) {
    switch (t.status) {
      case _TaskStatus.pending:
        return const Icon(Icons.hourglass_empty, color: Colors.grey);
      case _TaskStatus.running:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _TaskStatus.done:
        return const Icon(Icons.check_circle, color: Colors.green);
      case _TaskStatus.error:
        return const Icon(Icons.error, color: Colors.red);
    }
  }
}

enum _TaskStatus { pending, running, done, error }

class _ImageTask {
  _ImageTask({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
  _TaskStatus status = _TaskStatus.pending;
  String? label;
  String? error;
}
