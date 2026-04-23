import 'dart:convert';
import 'dart:typed_data';

import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/screens/report_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FollowUpScreen extends StatefulWidget {
  const FollowUpScreen({super.key});

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isSending = false;
  ReportModel? _selected;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  List<ReportModel> _threadReports(List<ReportModel> reports) {
    return reports.where((r) {
      final hasWorker =
          r.mergedConversation.any((m) => m.sender.toLowerCase() == 'worker');
      final hasUnread = r.hasUnreadCompany;
      return hasWorker || hasUnread;
    }).toList();
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

  String _statusLabel(String status) {
    switch (status) {
      case 'resolved':
        return '已解決';
      case 'in_progress':
        return '處理中';
      default:
        return '待處理';
    }
  }

  String _threadSummary(ReportModel report) {
    final meta = [
      '#${report.id ?? '-'}',
      _categoryLabel(report.category),
      _statusLabel(report.status),
    ].join(' · ');
    return meta;
  }

  String _conversationTitle(ReportModel report) {
    final location = report.location?.trim();
    if (location != null && location.isNotEmpty) {
      return '對話：${report.title} · ${_statusLabel(report.status)}';
    }
    return '對話：${report.title}';
  }

  Future<void> _openReportDetail(ReportModel report) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(report: report),
      ),
    );
  }

  void _selectReport(ReportModel report) async {
    setState(() => _selected = report);
    await context.read<ReportProvider>().clearUnreadCompany(report);
  }

  Uint8List? _decodeBase64Safe(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final cleaned = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkImage(String value) {
    final v = value.toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  void _openImageViewer(Widget imageWidget) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: imageWidget,
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageImage(String? imageRaw) {
    if (imageRaw == null || imageRaw.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isNetworkImage(imageRaw)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () => _openImageViewer(
            Image.network(imageRaw, fit: BoxFit.contain),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageRaw,
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }

    final bytes = _decodeBase64Safe(imageRaw);
    if (bytes == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => _openImageViewer(
          Image.memory(bytes, fit: BoxFit.contain),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            height: 130,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  String? _resolveMessageImage(
    ReportModel report,
    ConversationMessage message,
    int index,
    List<ConversationMessage> messages,
  ) {
    if (message.image != null && message.image!.trim().isNotEmpty) {
      return message.image;
    }

    // Legacy fallback: some data keeps latest worker image in worker_response_image
    // while conversation items may only have text.
    if ((report.workerResponseImage ?? '').trim().isEmpty) {
      return null;
    }
    if (message.sender.toLowerCase() != 'worker') {
      return null;
    }

    final isLastMessage = index == messages.length - 1;
    final textMatchesLatest = (report.workerResponse ?? '').trim().isNotEmpty &&
        message.text.trim() == (report.workerResponse ?? '').trim();

    if (isLastMessage || textMatchesLatest) {
      return report.workerResponseImage;
    }
    return null;
  }

  Future<void> _send() async {
    final report = _selected;
    if (report == null) return;
    if (report.status == 'resolved') return;

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final ok = await context
        .read<ReportProvider>()
        .submitWorkerResponse(report, text, null);

    if (!mounted) return;
    setState(() {
      _isSending = false;
      if (ok) _textController.clear();
    });

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已發送跟進回覆')),
      );
      await context.read<ReportProvider>().refreshFromCloud();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('發送失敗')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final threads = _threadReports(provider.reports)
      ..sort((a, b) =>
          (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));

    final bottomPadding = MediaQuery.of(context).padding.bottom + 124;

    if (_selected != null) {
      final latest = threads.cast<ReportModel?>().firstWhere(
            (r) => r?.id == _selected!.id,
            orElse: () => _selected,
          );
      _selected = latest;
    }

    if (_selected != null &&
        threads.isNotEmpty &&
        !threads.any((r) => r.id == _selected!.id)) {
      _selected = null;
    }

    return Column(
      children: [
        if (_selected == null)
          Expanded(
            child: threads.isEmpty
                ? const Center(
                    child: Text('暫無跟進對話'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: threads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final report = threads[index];
                      final selected = _selected?.id == report.id;
                      final last = report.mergedConversation.isNotEmpty
                          ? report.mergedConversation.last
                          : null;
                      return ListTile(
                        tileColor: selected
                            ? Colors.blue.shade50
                            : Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: selected
                                ? Colors.blue.shade300
                                : Colors.grey.shade200,
                          ),
                        ),
                        title: Text(
                          report.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_threadSummary(report)}\n${last?.text ?? '（尚無訊息）'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: report.hasUnreadCompany
                            ? Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        onTap: () => _selectReport(report),
                      );
                    },
                  ),
          )
        else
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _conversationTitle(_selected!),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _threadSummary(_selected!),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: '回到列表',
                              onPressed: () => setState(() => _selected = null),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _openReportDetail(_selected!),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('查看對應 report'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _metaChip(
                                '類別', _categoryLabel(_selected!.category)),
                            _metaChip('狀態', _statusLabel(_selected!.status)),
                            _metaChip('風險', _selected!.riskLevel),
                            _metaChip(
                              '更新',
                              DateFormat('MM/dd HH:mm').format(
                                (_selected!.updatedAt ?? _selected!.createdAt)
                                    .toLocal(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        itemCount: _selected!.mergedConversation.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final messages = _selected!.mergedConversation;
                          final m = messages[index];
                          final messageImage = _resolveMessageImage(
                            _selected!,
                            m,
                            index,
                            messages,
                          );
                          final isCompany = m.sender == 'company';
                          return Align(
                            alignment: isCompany
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 320),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCompany
                                    ? Colors.blue.shade50
                                    : Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCompany
                                      ? Colors.blue.shade200
                                      : Colors.teal.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isCompany ? '公司' : '我',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isCompany
                                          ? Colors.blue.shade700
                                          : Colors.teal.shade700,
                                    ),
                                  ),
                                  _buildMessageImage(messageImage),
                                  const SizedBox(height: 4),
                                  Text(m.text),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MM/dd HH:mm')
                                        .format(m.timestamp.toLocal()),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                enabled: !_isSending &&
                                    _selected!.status != 'resolved',
                                maxLines: 4,
                                minLines: 2,
                                decoration: InputDecoration(
                                  hintText: _selected!.status == 'resolved'
                                      ? '對話已關閉'
                                      : '輸入跟進回覆...',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: (_isSending ||
                                        _selected!.status == 'resolved')
                                    ? null
                                    : _send,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                ),
                                child: _isSending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selected!.status == 'resolved'
                              ? '此 report 已關閉，無法再新增對話。'
                              : '輸入後可直接送出；若需要完整編輯 report，可按上方按鈕。',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _metaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
