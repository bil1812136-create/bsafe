import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/providers/report_provider.dart';
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

    if (_selected != null) {
      final latest = threads.cast<ReportModel?>().firstWhere(
            (r) => r?.id == _selected!.id,
            orElse: () => _selected,
          );
      _selected = latest;
    }

    return Column(
      children: [
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
                      tileColor:
                          selected ? Colors.blue.shade50 : Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                        last?.text ?? '（尚無訊息）',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                      onTap: () async {
                        setState(() => _selected = report);
                        await context
                            .read<ReportProvider>()
                            .clearUnreadCompany(report);
                      },
                    );
                  },
                ),
        ),
        if (_selected != null)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '對話: ${_selected!.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _selected!.mergedConversation.length,
                    itemBuilder: (context, index) {
                      final m = _selected!.mergedConversation[index];
                      final isCompany = m.sender == 'company';
                      return Align(
                        alignment: isCompany
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(maxWidth: 290),
                          decoration: BoxDecoration(
                            color: isCompany
                                ? Colors.blue.shade50
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
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
                              const SizedBox(height: 2),
                              Text(m.text),
                              const SizedBox(height: 2),
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
                const SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  enabled: !_isSending && _selected!.status != 'resolved',
                  decoration: InputDecoration(
                    hintText:
                        _selected!.status == 'resolved' ? '對話已關閉' : '輸入跟進回覆...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: (_isSending || _selected!.status == 'resolved')
                          ? null
                          : _send,
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
