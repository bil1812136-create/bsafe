import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/providers/language_provider.dart';
import 'package:bsafe_app/providers/navigation_provider.dart';
import 'package:bsafe_app/screens/report_detail_screen.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FollowUpScreen extends StatefulWidget {
  final ReportModel? initialReport;

  const FollowUpScreen({super.key, this.initialReport});

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  final TextEditingController _textController = TextEditingController();
  Timer? _flashTimer;
  bool _isSending = false;
  bool _showListView = false;
  bool _flashOn = false;
  String? _flashReportId;
  ReportModel? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialReport;
    if (_selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ReportProvider>().clearUnreadCompany(_selected!);
      });
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _startFlash(String? reportId) {
    if (reportId == null || reportId.isEmpty) return;

    _flashTimer?.cancel();
    setState(() {
      _flashReportId = reportId;
      _flashOn = true;
    });

    var ticks = 0;
    _flashTimer = Timer.periodic(const Duration(milliseconds: 220), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => _flashOn = !_flashOn);
      ticks += 1;
      if (ticks >= 6) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _flashOn = false;
          _flashReportId = null;
        });
      }
    });
  }

  void _handleBackPressed() {
    if (widget.initialReport != null && !_showListView) {
      setState(() {
        _showListView = true;
      });
      return;
    }

    if (_selected != null) {
      setState(() => _selected = null);
      return;
    }

    Navigator.pop(context);
  }

  List<ReportModel> _threadReports(List<ReportModel> reports) {
    return reports.where((r) {
      final hasWorker =
          r.mergedConversation.any((m) => m.sender.toLowerCase() == 'worker');
      return hasWorker || r.hasUnreadCompany || r.mergedConversation.isNotEmpty;
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

  String _threadSummary(ReportModel report, int displayNumber) {
    return [
      '#$displayNumber',
      _categoryLabel(report.category),
      _statusLabel(report.status),
    ].join(' · ');
  }

  int _threadDisplayNumber(ReportModel report) {
    final allReports = context.read<ReportProvider>().reports;
    final sorted = List<ReportModel>.from(allReports);
    sorted.sort((a, b) {
      final ai = a.id ?? 0;
      final bi = b.id ?? 0;
      return ai.compareTo(bi);
    });
    final index = sorted.indexWhere((r) => r.id == report.id);
    return index >= 0 ? index + 1 : 1;
  }

  String _conversationTitle(ReportModel report) {
    return '對話：${report.title} · ${_statusLabel(report.status)}';
  }

  Future<void> _openReportDetail(ReportModel report) async {
    if (widget.initialReport != null && widget.initialReport!.id == report.id) {
      Navigator.pop(context);
      return;
    }

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
    if (imageRaw == null || imageRaw.isEmpty) return const SizedBox.shrink();

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
    if (bytes == null) return const SizedBox.shrink();

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

    if ((report.workerResponseImage ?? '').trim().isEmpty) return null;
    if (message.sender.toLowerCase() != 'worker') return null;

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
    if (report == null || report.status == 'resolved') return;

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final ok = await context.read<ReportProvider>().submitWorkerResponse(
          report,
          text,
          null,
        );

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

  Widget _buildBottomNavigationBar() {
    final navigationProvider = context.read<NavigationProvider>();
    final languageProvider = context.read<LanguageProvider>();
    final unreadFollowups = context
        .watch<ReportProvider>()
        .reports
        .where((r) => r.hasUnreadCompany)
        .length;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: Colors.white.withOpacity(0.94),
            currentIndex: 4,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: Colors.grey.shade400,
            showUnselectedLabels: true,
            selectedFontSize: 12,
            unselectedFontSize: 10,
            onTap: (index) {
              if (index == 4) return;
              navigationProvider.setIndex(index);
              Navigator.pop(context);
            },
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded),
                activeIcon: const Icon(Icons.home_rounded),
                label: languageProvider.t('nav_home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.camera_alt_rounded),
                activeIcon: const Icon(Icons.camera_alt_rounded),
                label: languageProvider.t('nav_report'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.history_rounded),
                activeIcon: const Icon(Icons.history_rounded),
                label: languageProvider.t('nav_history'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.bar_chart_rounded),
                activeIcon: const Icon(Icons.bar_chart_rounded),
                label: languageProvider.t('nav_analysis'),
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.forum_rounded),
                    if (unreadFollowups > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                activeIcon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.forum_rounded),
                    if (unreadFollowups > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                label: languageProvider.t('nav_followup'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.place_rounded),
                activeIcon: const Icon(Icons.place_rounded),
                label: languageProvider.t('nav_location'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final threads = _threadReports(provider.reports)
      ..sort((a, b) =>
          (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));

    final bottomPadding = MediaQuery.of(context).padding.bottom + 124;
    final openedFromReportDetail = widget.initialReport != null;
    final selectedReport = _selected ?? widget.initialReport;

    if (_selected != null && !openedFromReportDetail) {
      final latest = threads.cast<ReportModel?>().firstWhere(
            (r) => r?.id == _selected!.id,
            orElse: () => _selected,
          );
      _selected = latest;
    }

    if (_selected != null &&
        !openedFromReportDetail &&
        threads.isNotEmpty &&
        !threads.any((r) => r.id == _selected!.id)) {
      _selected = null;
    }

    final showListView = _showListView || selectedReport == null;
    final detailFlashActive = selectedReport != null &&
        _flashReportId == selectedReport.id?.toString() &&
        _flashOn;

    return PopScope(
      canPop: !openedFromReportDetail || _showListView,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (openedFromReportDetail && !_showListView) {
          setState(() {
            _showListView = true;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: showListView
                    ? (threads.isEmpty
                        ? const Center(child: Text('暫無跟進對話'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: threads.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final report = threads[index];
                              final selected = selectedReport?.id == report.id;
                              final last = report.mergedConversation.isNotEmpty
                                  ? report.mergedConversation.last
                                  : null;
                              final displayNumber =
                                  _threadDisplayNumber(report);

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
                                  '${_threadSummary(report, displayNumber)}\n${last?.text ?? '（尚無訊息）'}',
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
                          ))
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          12,
                          12,
                          openedFromReportDetail ? 12 : bottomPadding,
                        ),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: detailFlashActive
                                    ? Colors.blue.shade50
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: detailFlashActive
                                      ? Colors.blue.shade300
                                      : Colors.grey.shade200,
                                  width: detailFlashActive ? 1.6 : 1,
                                ),
                                boxShadow: detailFlashActive
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.shade100,
                                          blurRadius: 18,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _conversationTitle(
                                                  selectedReport!),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _threadSummary(
                                                selectedReport!,
                                                _threadDisplayNumber(
                                                    selectedReport!),
                                              ),
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
                                        onPressed: _handleBackPressed,
                                        icon: const Icon(
                                            Icons.arrow_back_rounded),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _openReportDetail(selectedReport!),
                                        icon: const Icon(Icons.open_in_new,
                                            size: 18),
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
                                          '類別',
                                          _categoryLabel(
                                              selectedReport!.category)),
                                      _metaChip('狀態',
                                          _statusLabel(selectedReport!.status)),
                                      _metaChip('風險', selectedReport.riskLevel),
                                      _metaChip(
                                        '更新',
                                        DateFormat('MM/dd HH:mm').format(
                                          (selectedReport.updatedAt ??
                                                  selectedReport.createdAt)
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
                                  color: detailFlashActive
                                      ? Colors.blue.shade50.withOpacity(0.45)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: detailFlashActive
                                        ? Colors.blue.shade200
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: ListView.separated(
                                  itemCount:
                                      selectedReport.mergedConversation.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final messages =
                                        selectedReport.mergedConversation;
                                    final m = messages[index];
                                    final messageImage = _resolveMessageImage(
                                      selectedReport,
                                      m,
                                      index,
                                      messages,
                                    );
                                    final isCompany = m.sender == 'company';

                                    return Align(
                                      alignment: isCompany
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        constraints:
                                            const BoxConstraints(maxWidth: 320),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isCompany
                                              ? Colors.blue.shade50
                                              : Colors.teal.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isCompany
                                                ? Colors.blue.shade200
                                                : Colors.teal.shade200,
                                          ),
                                          boxShadow: detailFlashActive &&
                                                  index == 0
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.blue.shade100,
                                                    blurRadius: 14,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                              DateFormat('MM/dd HH:mm').format(
                                                  m.timestamp.toLocal()),
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
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _textController,
                                      enabled: !_isSending &&
                                          selectedReport.status != 'resolved',
                                      maxLines: 4,
                                      minLines: 2,
                                      decoration: InputDecoration(
                                        hintText:
                                            selectedReport.status == 'resolved'
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
                                              selectedReport.status ==
                                                  'resolved')
                                          ? null
                                          : _send,
                                      child: _isSending
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('送出'),
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
          ),
        ),
        bottomNavigationBar:
            openedFromReportDetail ? _buildBottomNavigationBar() : null,
      ),
    );
  }
}
