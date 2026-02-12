import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bsafe_app/models/uwb_model.dart';
import 'package:bsafe_app/models/inspection_model.dart';
import 'package:bsafe_app/services/uwb_service.dart';
import 'package:bsafe_app/services/desktop_serial_service.dart';
import 'package:bsafe_app/services/mobile_serial_service.dart';
import 'package:bsafe_app/providers/inspection_provider.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:bsafe_app/screens/calibration_screen.dart';

class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  late UwbService _uwbService;
  final ImagePicker _imagePicker = ImagePicker();
  bool _showSettings = false;
  bool _showPinList = true;
  bool _showFullSettings = false;

  // 串口設定
  int _baudRate = 115200;

  @override
  void initState() {
    super.initState();
    _uwbService = UwbService();
    _uwbService.loadAnchorsFromStorage();
  }

  @override
  void dispose() {
    _uwbService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _uwbService,
      child: Consumer2<UwbService, InspectionProvider>(
        builder: (context, uwbService, inspection, _) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;

          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: SafeArea(
              child: Column(
                children: [
                  // 頂部工具列（手機/桌面不同佈局）
                  isMobile
                      ? _buildMobileTopBar(uwbService, inspection)
                      : _buildTopBar(uwbService, inspection),
                  // 主要內容
                  Expanded(
                    child: isMobile
                        ? _buildMapArea(uwbService, inspection)
                        : Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildMapArea(uwbService, inspection),
                              ),
                              if (_showPinList)
                                SizedBox(
                                  width: 320,
                                  child: _buildPinListPanel(inspection),
                                ),
                              if (_showFullSettings) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 300,
                                  child: _buildFullSettingsPanel(uwbService),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
            floatingActionButton: _buildFAB(uwbService, inspection),
            // 手機底部導航列
            bottomNavigationBar:
                isMobile ? _buildMobileBottomBar(uwbService, inspection) : null,
          );
        },
      ),
    );
  }

  // ===== 手機版頂部工具列（簡化） =====
  Widget _buildMobileTopBar(
      UwbService uwbService, InspectionProvider inspection) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // App 標題
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8)
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'B-SAFE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // UWB 連接狀態
          _buildConnectionChip(uwbService),

          const Spacer(),

          // 連接按鈕
          _buildConnectButton(uwbService),
          // 更多操作
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) => _handleMenuAction(value, inspection),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'new_session', child: Text('新建巡檢')),
              const PopupMenuItem(value: 'load_session', child: Text('載入巡檢')),
              const PopupMenuItem(value: 'export_pdf', child: Text('匯出 PDF')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'clear_pins', child: Text('清除所有 Pin')),
            ],
          ),
        ],
      ),
    );
  }

  // ===== 手機底部導航列 =====
  Widget _buildMobileBottomBar(
      UwbService uwbService, InspectionProvider inspection) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 巡檢點列表
              _buildBottomBarItem(
                icon: Icons.push_pin,
                label: '巡檢點(${inspection.currentPins.length})',
                onTap: () => _showMobilePinListSheet(inspection),
              ),
              // 快捷設置
              _buildBottomBarItem(
                icon: Icons.tune,
                label: '設置',
                onTap: () => _showMobileSettingsSheet(uwbService),
              ),
              // 座標顯示
              _buildBottomBarItem(
                icon: Icons.my_location,
                label: uwbService.currentTag != null
                    ? '${uwbService.currentTag!.x.toStringAsFixed(1)},${uwbService.currentTag!.y.toStringAsFixed(1)}'
                    : '未定位',
                onTap: () {},
                color:
                    uwbService.currentTag != null ? Colors.indigo : Colors.grey,
              ),
              // 校正
              _buildBottomBarItem(
                icon: Icons.straighten,
                label: '校正',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalibrationScreen(uwbService: uwbService),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? Colors.grey.shade700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, color: c, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ===== 手機版 Pin 列表 Bottom Sheet =====
  void _showMobilePinListSheet(InspectionProvider inspection) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖動手柄
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 標題
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Text('巡檢點',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    const Spacer(),
                    Text(
                      '${inspection.currentPins.length}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              if (inspection.currentPins.isNotEmpty)
                _buildPinSummary(inspection),
              // Pin 列表
              Expanded(
                child: inspection.currentPins.isEmpty
                    ? _buildEmptyPinState()
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: inspection.currentPins.length,
                        itemBuilder: (context, index) {
                          final pin = inspection.currentPins[index];
                          return _buildPinCard(pin, index, inspection);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 手機版設置 Bottom Sheet =====
  void _showMobileSettingsSheet(UwbService uwbService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => ListenableBuilder(
          listenable: uwbService,
          builder: (context, _) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text('設置',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 快捷開關
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildToggle('軌跡', Icons.timeline,
                                uwbService.config.showTrajectory, (v) {
                              uwbService.updateConfig(uwbService.config
                                  .copyWith(showTrajectory: v));
                            }),
                            _buildToggle(
                                '圍欄', Icons.fence, uwbService.config.showFence,
                                (v) {
                              uwbService.updateConfig(
                                  uwbService.config.copyWith(showFence: v));
                            }),
                            _buildToggle('平面圖', Icons.map,
                                uwbService.config.showFloorPlan, (v) {
                              uwbService.updateConfig(
                                  uwbService.config.copyWith(showFloorPlan: v));
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 操作按鈕
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => uwbService.clearTrajectory(),
                                icon: const Icon(Icons.delete_sweep, size: 18),
                                label: const Text('清除軌跡'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _loadFloorPlan(uwbService,
                                    context.read<InspectionProvider>()),
                                icon: const Icon(Icons.image, size: 18),
                                label: const Text('載入樓層圖'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 基站資訊
                        _buildSectionHeader('基站管理', Icons.cell_tower),
                        const SizedBox(height: 8),
                        ...uwbService.anchors.asMap().entries.map((entry) {
                          final index = entry.key;
                          final anchor = entry.value;
                          return _buildAnchorTile(anchor, index, uwbService);
                        }),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddAnchorDialog(uwbService),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加基站'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== 頂部工具列 =====
  Widget _buildTopBar(UwbService uwbService, InspectionProvider inspection) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // App 標題
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8)
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  'B-SAFE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // UWB 連接狀態
          _buildConnectionChip(uwbService),
          const SizedBox(width: 8),

          // 當前坐標
          if (uwbService.isConnected && uwbService.currentTag != null)
            _buildCoordinateChip(uwbService),

          const Spacer(),

          // 會話名稱
          if (inspection.currentSession != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text(
                    inspection.currentSession!.name,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${inspection.currentPins.length} pins)',
                    style: TextStyle(
                      color: Colors.blue.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(width: 8),

          // 工具按鈕列
          IconButton(
            onPressed: () => setState(() => _showSettings = !_showSettings),
            icon: Icon(
              _showSettings ? Icons.settings : Icons.settings_outlined,
              color:
                  _showSettings ? AppTheme.primaryColor : Colors.grey.shade600,
            ),
            tooltip: '顯示設置',
          ),
          IconButton(
            onPressed: () =>
                setState(() => _showFullSettings = !_showFullSettings),
            icon: Icon(
              Icons.tune,
              color: _showFullSettings ? Colors.orange : Colors.grey.shade600,
            ),
            tooltip: '完整設置',
          ),
          IconButton(
            onPressed: () => setState(() => _showPinList = !_showPinList),
            icon: Icon(
              _showPinList ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              color:
                  _showPinList ? AppTheme.primaryColor : Colors.grey.shade600,
            ),
            tooltip: '巡檢點列表',
          ),
          const SizedBox(width: 4),
          // 連接按鈕
          _buildConnectButton(uwbService),
          const SizedBox(width: 4),
          // 更多操作
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value, inspection),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'new_session', child: Text('新建巡檢')),
              const PopupMenuItem(value: 'load_session', child: Text('載入巡檢')),
              const PopupMenuItem(value: 'export_pdf', child: Text('匯出 PDF')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'clear_pins', child: Text('清除所有 Pin')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionChip(UwbService uwbService) {
    final isConnected = uwbService.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected
                ? (uwbService.isRealDevice ? 'UWB 已連接' : '模擬模式')
                : 'UWB 未連接',
            style: TextStyle(
              color: isConnected ? Colors.green.shade700 : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateChip(UwbService uwbService) {
    final tag = uwbService.currentTag!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.my_location, size: 14, color: Colors.indigo.shade600),
          const SizedBox(width: 6),
          Text(
            'X: ${tag.x.toStringAsFixed(2)}  Y: ${tag.y.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.indigo.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectButton(UwbService uwbService) {
    return uwbService.isConnected
        ? OutlinedButton.icon(
            onPressed: () => uwbService.disconnect(),
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('斷開'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          )
        : ElevatedButton.icon(
            onPressed: () => _showConnectDialog(uwbService),
            icon: const Icon(Icons.usb, size: 16),
            label: const Text('連接'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          );
  }

  // ===== 地圖區域 =====
  Widget _buildMapArea(UwbService uwbService, InspectionProvider inspection) {
    return Column(
      children: [
        // 快捷設置面板
        if (_showSettings) _buildQuickSettings(uwbService),

        // 地圖畫布
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                // UWB 畫布 + Pin 覆蓋層
                _buildInspectionCanvas(uwbService, inspection),

                // Pin 模式指示
                if (inspection.isPinMode)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.push_pin,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              MediaQuery.of(context).size.width < 600
                                  ? '點擊畫布放置 Pin'
                                  : '點擊畫布放置 Pin，或按「使用當前位置」',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 載入樓層平面圖按鈕 (當沒有 floor plan 時)
                if (uwbService.floorPlanImage == null &&
                    !uwbService.config.showFloorPlan)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: ElevatedButton.icon(
                      onPressed: () => _loadFloorPlan(uwbService, inspection),
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('載入樓層圖'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        elevation: 4,
                      ),
                    ),
                  ),

                // 距離 Debug 面板 (顯示各基站距離)
                if (uwbService.isConnected && uwbService.currentTag != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('距離 Debug',
                              style: TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          ...uwbService.currentTag!.anchorDistances.entries
                              .map((e) {
                            final isMin = uwbService
                                        .currentTag!.anchorDistances.values
                                        .where((v) => v > 0)
                                        .fold<double>(double.infinity, min) ==
                                    e.value &&
                                e.value > 0;
                            return Text(
                              '${e.key}: ${e.value.toStringAsFixed(2)}m',
                              style: TextStyle(
                                color:
                                    isMin ? Colors.greenAccent : Colors.white,
                                fontSize: 10,
                                fontWeight:
                                    isMin ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          }),
                          const SizedBox(height: 2),
                          Text(
                            'pos: (${uwbService.currentTag!.x.toStringAsFixed(2)}, ${uwbService.currentTag!.y.toStringAsFixed(2)})',
                            style: const TextStyle(
                                color: Colors.cyanAccent, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== 帶 Pin 標記的巡檢畫布 =====
  Widget _buildInspectionCanvas(
      UwbService uwbService, InspectionProvider inspection) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            if (inspection.isPinMode) {
              // 將點擊位置轉換為 UWB 座標
              final uwbCoord = _canvasToUwb(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
                uwbService,
              );
              if (uwbCoord != null) {
                final pin = inspection.addPin(uwbCoord.dx, uwbCoord.dy);
                // 打開拍照對話框
                _showPhotoCaptureDialog(pin);
              }
            } else {
              // 檢查是否點擊了某個 pin
              _checkPinTap(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
                uwbService,
                inspection,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: inspection.isPinMode
                    ? Colors.orange.shade400
                    : Colors.grey.shade300,
                width: inspection.isPinMode ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                isComplex: true,
                willChange: true,
                painter: InspectionCanvasPainter(
                  anchors: uwbService.anchors,
                  currentTag: uwbService.currentTag,
                  trajectory: uwbService.trajectory,
                  config: uwbService.config,
                  floorPlanImage: uwbService.floorPlanImage,
                  pins: inspection.currentPins,
                  selectedPinId: inspection.selectedPin?.id,
                  padding: 40.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 將畫布座標轉為 UWB 座標
  Offset? _canvasToUwb(
      Offset canvasPos, Size canvasSize, UwbService uwbService) {
    if (uwbService.anchors.isEmpty) return null;

    final anchors = uwbService.anchors;
    const double padding = 40.0;
    final double minX = anchors.map((a) => a.x).reduce(min) - 1;
    final double maxX = anchors.map((a) => a.x).reduce(max) + 1;
    final double minY = anchors.map((a) => a.y).reduce(min) - 1;
    final double maxY = anchors.map((a) => a.y).reduce(max) + 1;

    final double rangeX = maxX - minX;
    final double rangeY = maxY - minY;

    final double scaleX = (canvasSize.width - padding * 2) / rangeX;
    final double scaleY = (canvasSize.height - padding * 2) / rangeY;
    final double scale = min(scaleX, scaleY);

    final double offsetX = (canvasSize.width - rangeX * scale) / 2;
    final double offsetY = (canvasSize.height - rangeY * scale) / 2;

    // 反向轉換 (canvas → uwb)
    final double uwbX = (canvasPos.dx - offsetX) / scale + minX;
    final double uwbY =
        (canvasSize.height - canvasPos.dy - offsetY) / scale + minY;

    return Offset(uwbX, uwbY);
  }

  /// 檢查是否點擊了某個 pin
  void _checkPinTap(Offset tapPos, Size canvasSize, UwbService uwbService,
      InspectionProvider inspection) {
    if (uwbService.anchors.isEmpty) return;

    final anchors = uwbService.anchors;
    const double padding = 40.0;
    final double minX = anchors.map((a) => a.x).reduce(min) - 1;
    final double maxX = anchors.map((a) => a.x).reduce(max) + 1;
    final double minY = anchors.map((a) => a.y).reduce(min) - 1;
    final double maxY = anchors.map((a) => a.y).reduce(max) + 1;

    final double rangeX = maxX - minX;
    final double rangeY = maxY - minY;

    final double scaleX = (canvasSize.width - padding * 2) / rangeX;
    final double scaleY = (canvasSize.height - padding * 2) / rangeY;
    final double scale = min(scaleX, scaleY);

    final double offsetXCanvas = (canvasSize.width - rangeX * scale) / 2;
    final double offsetYCanvas = (canvasSize.height - rangeY * scale) / 2;

    for (final pin in inspection.currentPins) {
      final pinCanvasX = offsetXCanvas + (pin.x - minX) * scale;
      final pinCanvasY =
          canvasSize.height - offsetYCanvas - (pin.y - minY) * scale;
      final dist = (tapPos - Offset(pinCanvasX, pinCanvasY)).distance;
      if (dist < 20) {
        inspection.selectPin(pin);
        return;
      }
    }
    inspection.deselectPin();
  }

  // ===== 快捷設置 =====
  Widget _buildQuickSettings(UwbService uwbService) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: isMobile
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildToggle(
                    '軌跡', Icons.timeline, uwbService.config.showTrajectory,
                    (v) {
                  uwbService.updateConfig(
                      uwbService.config.copyWith(showTrajectory: v));
                }),
                _buildToggle('圍欄', Icons.fence, uwbService.config.showFence,
                    (v) {
                  uwbService
                      .updateConfig(uwbService.config.copyWith(showFence: v));
                }),
                _buildToggle('平面圖', Icons.map, uwbService.config.showFloorPlan,
                    (v) {
                  uwbService.updateConfig(
                      uwbService.config.copyWith(showFloorPlan: v));
                }),
              ],
            )
          : Row(
              children: [
                _buildToggle(
                    '軌跡', Icons.timeline, uwbService.config.showTrajectory,
                    (v) {
                  uwbService.updateConfig(
                      uwbService.config.copyWith(showTrajectory: v));
                }),
                _buildToggle('圍欄', Icons.fence, uwbService.config.showFence,
                    (v) {
                  uwbService
                      .updateConfig(uwbService.config.copyWith(showFence: v));
                }),
                _buildToggle('平面圖', Icons.map, uwbService.config.showFloorPlan,
                    (v) {
                  uwbService.updateConfig(
                      uwbService.config.copyWith(showFloorPlan: v));
                }),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.orange),
                  onPressed: () => uwbService.clearTrajectory(),
                  tooltip: '清除軌跡',
                ),
                IconButton(
                  icon: const Icon(Icons.image, color: AppTheme.primaryColor),
                  onPressed: () => _loadFloorPlan(
                      uwbService, context.read<InspectionProvider>()),
                  tooltip: '載入樓層圖',
                ),
              ],
            ),
    );
  }

  Widget _buildToggle(
      String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: value,
        onSelected: onChanged,
        avatar: Icon(
          icon,
          size: 16,
          color: value ? AppTheme.primaryColor : Colors.grey.shade600,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: value ? FontWeight.w600 : FontWeight.normal,
            color: value ? AppTheme.primaryColor : Colors.grey.shade800,
          ),
        ),
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        backgroundColor: Colors.grey.shade100,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }

  // ===== Pin 列表面板 =====
  Widget _buildPinListPanel(InspectionProvider inspection) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // 面板標題
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.push_pin,
                    size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '巡檢點',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${inspection.currentPins.length}',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          // 統計摘要
          if (inspection.currentPins.isNotEmpty) _buildPinSummary(inspection),

          // Pin 列表
          Expanded(
            child: inspection.currentPins.isEmpty
                ? _buildEmptyPinState()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: inspection.currentPins.length,
                    itemBuilder: (context, index) {
                      final pin = inspection.currentPins[index];
                      return _buildPinCard(pin, index, inspection);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinSummary(InspectionProvider inspection) {
    final session = inspection.currentSession;
    if (session == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _buildStatBadge('總計', session.totalPins.toString(), Colors.blue),
          const SizedBox(width: 8),
          _buildStatBadge('已分析', session.analyzedPins.toString(), Colors.green),
          const SizedBox(width: 8),
          _buildStatBadge('高風險', session.highRiskPins.toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style:
                  TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPinState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.push_pin_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            '尚無巡檢點',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '點擊下方「+」按鈕\n在當前位置添加巡檢點',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPinCard(
      InspectionPin pin, int index, InspectionProvider inspection) {
    final isSelected = inspection.selectedPin?.id == pin.id;
    final riskColor = _getRiskColor(pin.riskLevel);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => inspection.selectPin(pin),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Pin 序號 + 風險圖示
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: pin.isAnalyzed
                          ? riskColor.withValues(alpha: 0.15)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: pin.isAnalyzed ? riskColor : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 座標與狀態
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '(${pin.x.toStringAsFixed(2)}, ${pin.y.toStringAsFixed(2)})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pin.isAnalyzed
                                    ? riskColor.withValues(alpha: 0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pin.isAnalyzed
                                    ? pin.riskLevelLabel
                                    : pin.statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      pin.isAnalyzed ? riskColor : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (pin.isAnalyzed) ...[
                              const SizedBox(width: 6),
                              Text(
                                '風險: ${pin.riskScore}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 縮略圖 / 操作
                  if (pin.imageBase64 != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        base64Decode(pin.imageBase64!),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.camera_alt, size: 20),
                      color: Colors.grey,
                      onPressed: () => _showPhotoCaptureDialog(pin),
                      tooltip: '拍照分析',
                    ),
                  // 刪除
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: Colors.grey.shade400,
                    onPressed: () => _confirmDeletePin(pin, inspection),
                    tooltip: '刪除',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
              // 分析結果描述
              if (pin.isAnalyzed && pin.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  pin.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              // 備註
              if (pin.note != null && pin.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.note, size: 12, color: Colors.amber.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        pin.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: Colors.amber.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===== 浮動操作按鈕 =====
  Widget _buildFAB(UwbService uwbService, InspectionProvider inspection) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin 模式按鈕 (點擊地圖放置)
        if (!inspection.isPinMode)
          FloatingActionButton.small(
            heroTag: 'pin_mode',
            onPressed: () => inspection.togglePinMode(),
            backgroundColor: Colors.orange,
            tooltip: '點擊地圖放置 Pin',
            child: const Icon(Icons.touch_app, color: Colors.white),
          ),
        if (inspection.isPinMode)
          FloatingActionButton.small(
            heroTag: 'cancel_pin',
            onPressed: () => inspection.disablePinMode(),
            backgroundColor: Colors.grey,
            tooltip: '取消放置模式',
            child: const Icon(Icons.close, color: Colors.white),
          ),
        const SizedBox(height: 8),
        // 在當前 UWB 位置放置 Pin
        FloatingActionButton(
          heroTag: 'add_pin',
          onPressed: uwbService.isConnected && uwbService.currentTag != null
              ? () {
                  final tag = uwbService.currentTag!;
                  final pin = inspection.addPin(tag.x, tag.y);
                  _showPhotoCaptureDialog(pin);
                }
              : null,
          backgroundColor:
              uwbService.isConnected && uwbService.currentTag != null
                  ? AppTheme.primaryColor
                  : Colors.grey,
          tooltip: '在當前位置添加 Pin',
          child: const Icon(Icons.add_location_alt, color: Colors.white),
        ),
      ],
    );
  }

  // ===== 拍照 + AI 分析對話框 =====
  void _showPhotoCaptureDialog(InspectionPin pin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PhotoAnalysisDialog(
          pin: pin,
          imagePicker: _imagePicker,
          onComplete: (updatedPin) {
            context.read<InspectionProvider>().updatePin(updatedPin);
          },
        );
      },
    );
  }

  // ===== 刪除確認 =====
  void _confirmDeletePin(InspectionPin pin, InspectionProvider inspection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除巡檢點'),
        content: Text(
            '確定要刪除座標 (${pin.x.toStringAsFixed(2)}, ${pin.y.toStringAsFixed(2)}) 的巡檢點嗎？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              inspection.removePin(pin.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===== 載入樓層圖 =====
  Future<void> _loadFloorPlan(
      UwbService uwbService, InspectionProvider inspection) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'pdf'],
      dialogTitle: '選擇樓層平面圖',
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      await uwbService.loadFloorPlanImage(path);
      uwbService.updateConfig(uwbService.config.copyWith(showFloorPlan: true));
      inspection.updateFloorPlan(path);
    }
  }

  // ===== 連接對話框 =====
  void _showConnectDialog(UwbService uwbService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.usb, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Text('連接 UWB 設備',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildConnectOption(
              icon: Icons.wifi_tethering,
              title: '自動連接 BU04',
              subtitle: '通過 USB 串口 / USB-C OTG 連接安信可 UWB 設備',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(ctx);
                _showSerialConnectDialog(uwbService);
              },
            ),
            const SizedBox(height: 12),
            _buildConnectOption(
              icon: Icons.play_circle_outline,
              title: '模擬演示模式',
              subtitle: '使用模擬數據演示 UWB 定位功能',
              color: Colors.green,
              onTap: () {
                Navigator.pop(ctx);
                uwbService.connect(simulate: true);
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '電腦：確保 BU04 已通過 USB 連接並安裝 CH340/CP210x 驅動。\n手機：用 USB-C 線連接 BU04，需支援 OTG。',
                      style:
                          TextStyle(color: Colors.blue.shade900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }

  void _showSerialConnectDialog(UwbService uwbService) {
    if (kIsWeb) return;

    // Android 平台：使用 USB OTG
    if (!kIsWeb && Platform.isAndroid) {
      _showMobileUsbConnectDialog(uwbService);
      return;
    }

    // 桌面平台：使用 COM 串口
    List<String> ports = [];
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final serialService = DesktopSerialService();
      ports = serialService.getAvailablePorts();
    }

    if (ports.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.usb_off, color: Colors.red),
              SizedBox(width: 8),
              Text('未找到串口'),
            ],
          ),
          content: const Text('未檢測到任何串口設備。確認 BU04 已連接並安裝驅動。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('確定')),
          ],
        ),
      );
      return;
    }

    String selectedPort = ports.first;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('選擇串口'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedPort,
                items: ports
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedPort = v);
                },
                decoration: const InputDecoration(
                  labelText: '串口',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _baudRate,
                items: [9600, 19200, 38400, 57600, 115200]
                    .map((b) => DropdownMenuItem(value: b, child: Text('$b')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => _baudRate = v);
                },
                decoration: const InputDecoration(
                  labelText: '波特率',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                uwbService.connect(
                  simulate: false,
                  port: selectedPort,
                  baudRate: _baudRate,
                );
              },
              child: const Text('連接'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Android USB OTG 連接對話框 =====
  void _showMobileUsbConnectDialog(UwbService uwbService) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _MobileUsbConnectDialog(uwbService: uwbService, baudRate: _baudRate),
    );
  }

  // ===== 完整設定面板 =====
  Widget _buildFullSettingsPanel(UwbService uwbService) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.white),
                const SizedBox(width: 8),
                const Text('設置',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.white),
                  onPressed: () => setState(() => _showFullSettings = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- 基站管理 ----
                  _buildSectionHeader('基站管理', Icons.cell_tower),
                  const SizedBox(height: 8),
                  ...uwbService.anchors.asMap().entries.map((entry) {
                    final index = entry.key;
                    final anchor = entry.value;
                    return _buildAnchorTile(anchor, index, uwbService);
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddAnchorDialog(uwbService),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加基站'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CalibrationScreen(uwbService: uwbService),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('基站校正設置'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ---- 平面圖設置 ----
                  _buildSectionHeader('平面圖設置', Icons.map),
                  const SizedBox(height: 8),

                  // 載入按鈕
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _loadFloorPlan(
                              uwbService, context.read<InspectionProvider>()),
                          icon: uwbService.isLoadingFloorPlan
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.folder_open, size: 16),
                          label: Text(uwbService.isLoadingFloorPlan
                              ? '載入中...'
                              : '打開平面圖'),
                        ),
                      ),
                      if (uwbService.config.floorPlanImagePath != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            uwbService.clearFloorPlan();
                            setState(() {});
                          },
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          tooltip: '清除地圖',
                        ),
                      ],
                    ],
                  ),

                  // 顯示/隱藏平面圖
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: uwbService.config.showFloorPlan,
                    onChanged: (v) {
                      uwbService.updateConfig(
                          uwbService.config.copyWith(showFloorPlan: v));
                      setState(() {});
                    },
                    title: const Text('顯示平面圖', style: TextStyle(fontSize: 13)),
                  ),

                  // 透明度
                  if (uwbService.config.floorPlanImagePath != null) ...[
                    Row(
                      children: [
                        const SizedBox(
                            width: 60,
                            child: Text('透明度', style: TextStyle(fontSize: 13))),
                        Expanded(
                          child: Slider(
                            value: uwbService.config.floorPlanOpacity,
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            label:
                                '${(uwbService.config.floorPlanOpacity * 100).toInt()}%',
                            onChanged: (v) {
                              uwbService.updateFloorPlanOpacity(v);
                              setState(() {});
                            },
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${(uwbService.config.floorPlanOpacity * 100).toInt()}%',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),

                    const Divider(),

                    // 偏移設置
                    const Text('偏移設置',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    _buildNumberField('X 偏移 (米)', uwbService.config.xOffset,
                        (v) {
                      uwbService
                          .updateConfig(uwbService.config.copyWith(xOffset: v));
                    }),
                    _buildNumberField('Y 偏移 (米)', uwbService.config.yOffset,
                        (v) {
                      uwbService
                          .updateConfig(uwbService.config.copyWith(yOffset: v));
                    }),
                    const SizedBox(height: 8),

                    // 比例設置
                    const Text('比例設置',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    _buildNumberField('X 比例 (像素/米)', uwbService.config.xScale,
                        (v) {
                      uwbService
                          .updateConfig(uwbService.config.copyWith(xScale: v));
                    }),
                    _buildNumberField('Y 比例 (像素/米)', uwbService.config.yScale,
                        (v) {
                      uwbService
                          .updateConfig(uwbService.config.copyWith(yScale: v));
                    }),
                    const SizedBox(height: 8),

                    // 翻轉設置
                    const Text('翻轉設置',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: uwbService.config.flipX,
                            onChanged: (v) {
                              uwbService.updateConfig(uwbService.config
                                  .copyWith(flipX: v ?? false));
                              setState(() {});
                            },
                            title: const Text('翻轉 X',
                                style: TextStyle(fontSize: 12)),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: uwbService.config.flipY,
                            onChanged: (v) {
                              uwbService.updateConfig(uwbService.config
                                  .copyWith(flipY: v ?? false));
                              setState(() {});
                            },
                            title: const Text('翻轉 Y',
                                style: TextStyle(fontSize: 12)),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                      ],
                    ),

                    // 提示
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '提示：X/Y比例 = 圖片上每米對應的像素數\n偏移 = 圖片左下角在 UWB 座標系中的位置',
                        style: TextStyle(
                            fontSize: 11, color: Colors.blue.shade800),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ---- 顯示設置 ----
                  _buildSectionHeader('顯示設置', Icons.visibility),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: uwbService.config.showTrajectory,
                    onChanged: (v) => uwbService.updateConfig(
                        uwbService.config.copyWith(showTrajectory: v)),
                    title: const Text('顯示軌跡', style: TextStyle(fontSize: 13)),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: uwbService.config.showFence,
                    onChanged: (v) => uwbService
                        .updateConfig(uwbService.config.copyWith(showFence: v)),
                    title: const Text('顯示圍欄', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _buildAnchorTile(UwbAnchor anchor, int index, UwbService uwbService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cell_tower,
              size: 20, color: anchor.isActive ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(anchor.id,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '(${anchor.x}, ${anchor.y}, ${anchor.z})',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            color: AppTheme.primaryColor,
            onPressed: () => _showEditAnchorDialog(anchor, index, uwbService),
            tooltip: '編輯坐標',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.red.shade400,
            onPressed: () {
              uwbService.removeAnchor(index);
              setState(() {});
            },
            tooltip: '刪除',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _showEditAnchorDialog(
      UwbAnchor anchor, int index, UwbService uwbService) {
    final xController = TextEditingController(text: anchor.x.toString());
    final yController = TextEditingController(text: anchor.y.toString());
    final zController = TextEditingController(text: anchor.z.toString());
    final nameController = TextEditingController(text: anchor.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit_location_alt, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('編輯 ${anchor.id}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '基站名稱',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: xController,
                    decoration: const InputDecoration(
                      labelText: 'X (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: yController,
                    decoration: const InputDecoration(
                      labelText: 'Y (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: zController,
                    decoration: const InputDecoration(
                      labelText: 'Z (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              final newAnchor = UwbAnchor(
                id: newName.isNotEmpty ? newName : anchor.id,
                x: double.tryParse(xController.text) ?? anchor.x,
                y: double.tryParse(yController.text) ?? anchor.y,
                z: double.tryParse(zController.text) ?? anchor.z,
                isActive: anchor.isActive,
              );
              uwbService.updateAnchor(index, newAnchor);
              if (newName.isNotEmpty && newName != anchor.id) {
                uwbService.renameAnchor(index, newName);
              }
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAddAnchorDialog(UwbService uwbService) {
    final xController = TextEditingController(text: '0.0');
    final yController = TextEditingController(text: '0.0');
    final zController = TextEditingController(text: '3.0');
    final nameController =
        TextEditingController(text: '基站${uwbService.anchors.length}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_location, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('添加基站'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '基站名稱',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: xController,
                    decoration: const InputDecoration(
                      labelText: 'X (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: yController,
                    decoration: const InputDecoration(
                      labelText: 'Y (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: zController,
                    decoration: const InputDecoration(
                      labelText: 'Z (m)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              uwbService.addAnchor(UwbAnchor(
                id: nameController.text.trim().isNotEmpty
                    ? nameController.text.trim()
                    : '基站${uwbService.anchors.length}',
                x: double.tryParse(xController.text) ?? 0.0,
                y: double.tryParse(yController.text) ?? 0.0,
                z: double.tryParse(zController.text) ?? 3.0,
                isActive: true,
              ));
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(
      String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextFormField(
                initialValue: value.toString(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                style: const TextStyle(fontSize: 13),
                onFieldSubmitted: (text) {
                  final v = double.tryParse(text);
                  if (v != null) {
                    onChanged(v);
                  }
                },
                onChanged: (text) {
                  // 只在輸入完整數字時更新（包含小數點後的數字）
                  if (text.isEmpty || text == '-' || text.endsWith('.')) {
                    return; // 允許輸入中間狀態
                  }
                  final v = double.tryParse(text);
                  if (v != null) {
                    onChanged(v);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 選單操作 =====
  void _handleMenuAction(String action, InspectionProvider inspection) {
    switch (action) {
      case 'new_session':
        _showNewSessionDialog(inspection);
        break;
      case 'load_session':
        _showLoadSessionDialog(inspection);
        break;
      case 'export_pdf':
        _exportPdf(inspection);
        break;
      case 'clear_pins':
        if (inspection.currentPins.isNotEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('清除所有巡檢點'),
              content: const Text('確定要清除所有巡檢點嗎？此操作無法撤銷。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    for (final pin in List.from(inspection.currentPins)) {
                      inspection.removePin(pin.id);
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child:
                      const Text('清除', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        break;
    }
  }

  void _showNewSessionDialog(InspectionProvider inspection) {
    final controller = TextEditingController(
      text: '巡檢 ${DateTime.now().toString().substring(0, 16)}',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建巡檢會話'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '會話名稱',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              inspection.createSession(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('建立'),
          ),
        ],
      ),
    );
  }

  void _showLoadSessionDialog(InspectionProvider inspection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('載入巡檢會話'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: inspection.sessions.isEmpty
              ? const Center(child: Text('沒有保存的巡檢會話'))
              : ListView.builder(
                  itemCount: inspection.sessions.length,
                  itemBuilder: (context, index) {
                    final session = inspection.sessions[index];
                    return ListTile(
                      title: Text(session.name),
                      subtitle: Text(
                          '${session.totalPins} 個巡檢點  ${session.createdAt.toString().substring(0, 16)}'),
                      trailing: session.id == inspection.currentSession?.id
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        inspection.switchSession(session.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('關閉')),
        ],
      ),
    );
  }

  // ===== PDF 匯出 =====
  Future<void> _exportPdf(InspectionProvider inspection) async {
    if (inspection.currentPins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('沒有巡檢點可以匯出'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 選擇保存路徑
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存巡檢報告 PDF',
      fileName: '巡檢報告_${DateTime.now().toString().substring(0, 10)}.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputPath == null) return;

    try {
      await _generatePdfReport(outputPath, inspection);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF 已保存至: $outputPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        inspection.markExported();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯出失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generatePdfReport(
      String outputPath, InspectionProvider inspection) async {
    // 使用 basic file writing 生成簡單的 HTML/文字報告
    // (完整的 PDF 生成需要 pdf package)
    final session = inspection.currentSession!;
    final buffer = StringBuffer();

    buffer.writeln('B-SAFE 巡檢報告');
    buffer.writeln('=' * 50);
    buffer.writeln('會話名稱: ${session.name}');
    buffer.writeln('建立時間: ${session.createdAt}');
    buffer.writeln('巡檢點數: ${session.totalPins}');
    buffer.writeln('已分析: ${session.analyzedPins}');
    buffer.writeln('高風險: ${session.highRiskPins}');
    buffer.writeln('平均風險: ${session.averageRiskScore.toStringAsFixed(1)}');
    buffer.writeln('');
    buffer.writeln('巡檢點詳細:');
    buffer.writeln('-' * 50);

    for (int i = 0; i < session.pins.length; i++) {
      final pin = session.pins[i];
      buffer.writeln('');
      buffer.writeln('巡檢點 #${i + 1}');
      buffer.writeln(
          '  座標: (${pin.x.toStringAsFixed(2)}, ${pin.y.toStringAsFixed(2)})');
      buffer.writeln('  狀態: ${pin.statusLabel}');
      buffer.writeln('  風險等級: ${pin.riskLevelLabel}');
      buffer.writeln('  風險評分: ${pin.riskScore}');
      if (pin.description != null) {
        buffer.writeln('  AI 分析: ${pin.description}');
      }
      if (pin.recommendations.isNotEmpty) {
        buffer.writeln('  建議:');
        for (final rec in pin.recommendations) {
          buffer.writeln('    - $rec');
        }
      }
      if (pin.note != null) {
        buffer.writeln('  備註: ${pin.note}');
      }
    }

    // 保存為純文字 (PDF 完整生成可後續加入 pdf package)
    final file = File(outputPath.replaceAll('.pdf', '.txt'));
    await file.writeAsString(buffer.toString());

    debugPrint('✅ 報告已匯出至: ${file.path}');
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// ===== 拍照 + AI 分析對話框 Widget =====
class _PhotoAnalysisDialog extends StatefulWidget {
  final InspectionPin pin;
  final ImagePicker imagePicker;
  final ValueChanged<InspectionPin> onComplete;

  const _PhotoAnalysisDialog({
    required this.pin,
    required this.imagePicker,
    required this.onComplete,
  });

  @override
  State<_PhotoAnalysisDialog> createState() => _PhotoAnalysisDialogState();
}

class _PhotoAnalysisDialogState extends State<_PhotoAnalysisDialog> {
  String? _imageBase64;
  String? _imagePath;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  final _noteController = TextEditingController();
  bool _photoTaken = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 標題
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '拍照 & AI 分析',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        Text(
                          '位置: (${widget.pin.x.toStringAsFixed(2)}, ${widget.pin.y.toStringAsFixed(2)})',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 內容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 照片區
                    if (_imageBase64 != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(_imageBase64!),
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.grey.shade300,
                              style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('選擇或拍攝照片',
                                style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // 拍照/選圖按鈕
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isAnalyzing
                                ? null
                                : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('拍照'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isAnalyzing
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('從檔案'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 備註
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: '備註 (可選)',
                        hintText: '輸入備註...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      maxLines: 2,
                    ),

                    // AI 分析中
                    if (_isAnalyzing) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('AI 正在分析...',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],

                    // AI 分析結果
                    if (_analysisResult != null) ...[
                      const SizedBox(height: 16),
                      _buildAnalysisResultCard(),
                    ],
                  ],
                ),
              ),
            ),

            // 底部按鈕
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('跳過'),
                  ),
                  const Spacer(),
                  if (_photoTaken && !_isAnalyzing)
                    ElevatedButton.icon(
                      onPressed: _analyzeImage,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('AI 分析'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isAnalyzing ? null : _saveAndClose,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      XFile? image;
      if (source == ImageSource.camera) {
        // 在桌面端用 file_picker 替代
        if (!kIsWeb &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            dialogTitle: '選擇照片',
          );
          if (result != null && result.files.single.path != null) {
            image = XFile(result.files.single.path!);
          }
        } else {
          image = await widget.imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
        }
      } else {
        // Gallery / File
        if (!kIsWeb &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            dialogTitle: '選擇照片',
          );
          if (result != null && result.files.single.path != null) {
            image = XFile(result.files.single.path!);
          }
        } else {
          image = await widget.imagePicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
        }
      }

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBase64 = base64Encode(bytes);
          _imagePath = image!.path;
          _photoTaken = true;
          _analysisResult = null;
        });
      }
    } catch (e) {
      debugPrint('選擇圖片失敗: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBase64 == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final provider = context.read<InspectionProvider>();
      final updatedPin = await provider.analyzePin(
        widget.pin,
        imageBase64: _imageBase64!,
        imagePath: _imagePath,
      );

      setState(() {
        _analysisResult = updatedPin.aiResult ??
            {
              'risk_level': updatedPin.riskLevel,
              'risk_score': updatedPin.riskScore,
              'analysis': updatedPin.description,
              'recommendations': updatedPin.recommendations,
            };
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      debugPrint('AI 分析錯誤: $e');
    }
  }

  void _saveAndClose() {
    var updatedPin = widget.pin;

    if (_imageBase64 != null) {
      updatedPin = updatedPin.copyWith(
        imageBase64: _imageBase64,
        imagePath: _imagePath,
      );
    }
    if (_noteController.text.isNotEmpty) {
      updatedPin = updatedPin.copyWith(note: _noteController.text);
    }
    if (_analysisResult != null) {
      updatedPin = updatedPin.copyWith(
        aiResult: _analysisResult,
        riskLevel: _analysisResult!['risk_level'] as String? ?? 'low',
        riskScore: _analysisResult!['risk_score'] as int? ?? 0,
        description: _analysisResult!['analysis'] as String?,
        recommendations: (_analysisResult!['recommendations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        status: 'analyzed',
      );
    }

    widget.onComplete(updatedPin);
    Navigator.pop(context);
  }

  Widget _buildAnalysisResultCard() {
    final riskLevel = _analysisResult!['risk_level'] as String? ?? 'low';
    final riskScore = _analysisResult!['risk_score'] as int? ?? 0;
    final analysis = _analysisResult!['analysis'] as String? ?? '';
    final recommendations =
        _analysisResult!['recommendations'] as List<dynamic>? ?? [];

    Color riskColor;
    switch (riskLevel) {
      case 'high':
        riskColor = Colors.red;
        break;
      case 'medium':
        riskColor = Colors.orange;
        break;
      default:
        riskColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: riskColor),
              const SizedBox(width: 8),
              const Text(
                'AI 分析結果',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '風險: $riskScore',
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(analysis, style: const TextStyle(fontSize: 13)),
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('建議:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ...recommendations.map((r) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 13)),
                      Expanded(
                          child: Text(r.toString(),
                              style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ===== Android USB OTG 連接對話框 =====
class _MobileUsbConnectDialog extends StatefulWidget {
  final UwbService uwbService;
  final int baudRate;

  const _MobileUsbConnectDialog(
      {required this.uwbService, required this.baudRate});

  @override
  State<_MobileUsbConnectDialog> createState() =>
      _MobileUsbConnectDialogState();
}

class _MobileUsbConnectDialogState extends State<_MobileUsbConnectDialog> {
  final MobileSerialService _mobileSerial = MobileSerialService();
  List<UsbDeviceInfo> _devices = [];
  bool _isScanning = true;
  bool _isConnecting = false;
  int _selectedIndex = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      final devices = await _mobileSerial.getAvailableDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
          if (devices.isEmpty) {
            _error =
                '未檢測到 USB 設備。\n請確認：\n• BU04 已透過 USB-C 線連接\n• 手機支援 USB OTG\n• 已授權 USB 存取';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _error = '掃描設備錯誤: $e';
        });
      }
    }
  }

  Future<void> _connectDevice() async {
    if (_devices.isEmpty || _selectedIndex >= _devices.length) return;

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    final device = _devices[_selectedIndex];
    final success = await widget.uwbService.connect(
      simulate: false,
      port: device.displayName,
      baudRate: widget.baudRate,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已連接 ${device.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isConnecting = false;
          _error = widget.uwbService.lastError ?? '連接失敗';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.usb, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          const Text('USB 設備連接'),
          const Spacer(),
          if (!_isScanning)
            IconButton(
              onPressed: _scanDevices,
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: '重新掃描',
            ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isScanning)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('正在掃描 USB 設備...'),
                    ],
                  ),
                ),
              )
            else if (_error != null && _devices.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.usb_off, color: Colors.red.shade400, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                '已找到 ${_devices.length} 個 USB 設備',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...List.generate(_devices.length, (i) {
                final d = _devices[i];
                final isSelected = i == _selectedIndex;
                return InkWell(
                  onTap: () => setState(() => _selectedIndex = i),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.usb,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                'VID: 0x${d.vid.toRadixString(16).toUpperCase()}  PID: 0x${d.pid.toRadixString(16).toUpperCase()}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                );
              }),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '用 USB-C 線將 BU04 連接手機，系統會自動偵測',
                      style:
                          TextStyle(color: Colors.blue.shade900, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton.icon(
          onPressed:
              (_devices.isEmpty || _isConnecting) ? null : _connectDevice,
          icon: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.link),
          label: Text(_isConnecting ? '連接中...' : '連接'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ===== 巡檢畫布 Painter (擴展 UWB Canvas 增加 Pin 繪製) =====
class InspectionCanvasPainter extends CustomPainter {
  final List<UwbAnchor> anchors;
  final UwbTag? currentTag;
  final List<TrajectoryPoint> trajectory;
  final UwbConfig config;
  final ui.Image? floorPlanImage;
  final List<InspectionPin> pins;
  final String? selectedPinId;
  final double padding;

  InspectionCanvasPainter({
    required this.anchors,
    this.currentTag,
    this.trajectory = const [],
    required this.config,
    this.floorPlanImage,
    this.pins = const [],
    this.selectedPinId,
    this.padding = 40.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (anchors.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    // 計算座標範圍
    final double minX = anchors.map((a) => a.x).reduce(min) - 1;
    final double maxX = anchors.map((a) => a.x).reduce(max) + 1;
    final double minY = anchors.map((a) => a.y).reduce(min) - 1;
    final double maxY = anchors.map((a) => a.y).reduce(max) + 1;

    final double rangeX = maxX - minX;
    final double rangeY = maxY - minY;

    final double scaleX = (size.width - padding * 2) / rangeX;
    final double scaleY = (size.height - padding * 2) / rangeY;
    final double scale = min(scaleX, scaleY);

    final double offsetX = (size.width - rangeX * scale) / 2;
    final double offsetY = (size.height - rangeY * scale) / 2;

    Offset toCanvas(double x, double y) {
      return Offset(
        offsetX + (x - minX) * scale,
        size.height - offsetY - (y - minY) * scale,
      );
    }

    // 繪製背景網格
    _drawGrid(canvas, size, minX, maxX, minY, maxY, scale, offsetX, offsetY,
        toCanvas);

    // 繪製平面地圖
    if (config.showFloorPlan && floorPlanImage != null) {
      _drawFloorPlan(canvas, size, minX, minY, scale, offsetX, offsetY);
    }

    // 繪製圍欄
    if (config.showFence && currentTag != null) {
      _drawFence(canvas, toCanvas, scale, currentTag!);
    }

    // 繪製軌跡
    if (config.showTrajectory && trajectory.isNotEmpty) {
      _drawTrajectory(canvas, toCanvas);
    }

    // 繪製基站
    for (var anchor in anchors) {
      _drawAnchor(canvas, toCanvas(anchor.x, anchor.y), anchor);
    }

    // 繪製標籤
    if (currentTag != null) {
      _drawTag(canvas, toCanvas(currentTag!.x, currentTag!.y), currentTag!);
    }

    // ---- 繪製巡檢 Pin ----
    for (int i = 0; i < pins.length; i++) {
      final pin = pins[i];
      final pos = toCanvas(pin.x, pin.y);
      _drawInspectionPin(canvas, pos, pin, i + 1, pin.id == selectedPinId);
    }

    // 繪製座標軸標籤
    _drawAxisLabels(canvas, size, minX, maxX, minY, maxY, scale, offsetX,
        offsetY, toCanvas);
  }

  void _drawInspectionPin(Canvas canvas, Offset position, InspectionPin pin,
      int index, bool isSelected) {
    // Pin 顏色
    Color pinColor;
    switch (pin.riskLevel) {
      case 'high':
        pinColor = Colors.red;
        break;
      case 'medium':
        pinColor = Colors.orange;
        break;
      case 'low':
        pinColor = Colors.green;
        break;
      default:
        pinColor = pin.isAnalyzed ? Colors.blue : Colors.grey;
    }

    // 選中時的光暈
    if (isSelected) {
      final glowPaint = Paint()
        ..color = pinColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(position, 20, glowPaint);
    }

    // Pin 圖釘形狀
    final pinPath = Path();
    pinPath.moveTo(position.dx, position.dy + 4);
    pinPath.lineTo(position.dx - 8, position.dy - 12);
    pinPath.quadraticBezierTo(
        position.dx - 12, position.dy - 22, position.dx, position.dy - 28);
    pinPath.quadraticBezierTo(
        position.dx + 12, position.dy - 22, position.dx + 8, position.dy - 12);
    pinPath.close();

    // 陰影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(pinPath.shift(const Offset(2, 2)), shadowPaint);

    // Pin 本體
    final pinPaint = Paint()
      ..color = pinColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // Pin 邊框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(pinPath, borderPaint);

    // 內部圓圈 (白點)
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(position.dx, position.dy - 16), 5, dotPaint);

    // Pin 序號
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$index',
        style: TextStyle(
          color: pinColor,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2,
          position.dy - 16 - textPainter.height / 2),
    );

    // 底部小點 (pin 著陸點)
    canvas.drawCircle(position, 3, Paint()..color = pinColor);
  }

  // ---- 以下方法與 UwbCanvasPainter 相同 ----

  void _drawEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '等待連接 UWB 設備...\n請先連接設備或載入樓層圖',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: size.width - 40);
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2),
    );
  }

  void _drawGrid(
      Canvas canvas,
      Size size,
      double minX,
      double maxX,
      double minY,
      double maxY,
      double scale,
      double offsetX,
      double offsetY,
      Offset Function(double, double) toCanvas) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 0.8;
    final majorGridPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5;
    final originPaint = Paint()
      ..color = Colors.blue.shade800
      ..strokeWidth = 2.5;

    final double startX = minX.floorToDouble();
    final double startY = minY.floorToDouble();

    for (double x = startX; x <= maxX; x += 0.5) {
      Paint paint;
      if ((x - 0.0).abs() < 0.01) {
        paint = originPaint;
      } else if (x % 1 == 0) {
        paint = majorGridPaint;
      } else {
        paint = gridPaint;
      }
      canvas.drawLine(toCanvas(x, minY), toCanvas(x, maxY), paint);
    }

    for (double y = startY; y <= maxY; y += 0.5) {
      Paint paint;
      if ((y - 0.0).abs() < 0.01) {
        paint = originPaint;
      } else if (y % 1 == 0) {
        paint = majorGridPaint;
      } else {
        paint = gridPaint;
      }
      canvas.drawLine(toCanvas(minX, y), toCanvas(maxX, y), paint);
    }
  }

  void _drawFloorPlan(Canvas canvas, Size size, double minX, double minY,
      double scale, double offsetX, double offsetY) {
    if (floorPlanImage == null) return;
    final img = floorPlanImage!;
    final imgWidth = img.width.toDouble();
    final imgHeight = img.height.toDouble();

    final double realWidth = imgWidth / config.xScale;
    final double realHeight = imgHeight / config.yScale;
    final double imgRealX = config.xOffset;
    final double imgRealY = config.yOffset;

    final double canvasLeft = offsetX + (imgRealX - minX) * scale;
    final double canvasTop =
        size.height - offsetY - ((imgRealY + realHeight) - minY) * scale;
    final double canvasWidth = realWidth * scale;
    final double canvasHeight = realHeight * scale;

    final srcRect = Rect.fromLTWH(0, 0, imgWidth, imgHeight);
    final dstRect =
        Rect.fromLTWH(canvasLeft, canvasTop, canvasWidth, canvasHeight);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, config.floorPlanOpacity);
    canvas.drawImageRect(img, srcRect, dstRect, paint);
  }

  void _drawFence(Canvas canvas, Offset Function(double, double) toCanvas,
      double scale, UwbTag tag) {
    final center = toCanvas(tag.x, tag.y);
    canvas.drawCircle(
        center,
        config.areaRadius1 * scale,
        Paint()
          ..color = Colors.green.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        center,
        config.areaRadius1 * scale,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawCircle(
        center,
        config.areaRadius2 * scale,
        Paint()
          ..color = Colors.orange.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill);
  }

  void _drawTrajectory(
      Canvas canvas, Offset Function(double, double) toCanvas) {
    if (trajectory.length < 2) return;
    for (int i = 1; i < trajectory.length; i++) {
      final opacity = i / trajectory.length;
      final paint = Paint()
        ..color = Colors.blue.withValues(alpha: opacity * 0.8)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        toCanvas(trajectory[i - 1].x, trajectory[i - 1].y),
        toCanvas(trajectory[i].x, trajectory[i].y),
        paint,
      );
    }
  }

  void _drawAnchor(Canvas canvas, Offset position, UwbAnchor anchor) {
    canvas.drawCircle(position, 8, Paint()..color = Colors.brown.shade700);
    final towerPaint = Paint()
      ..color = anchor.isActive ? Colors.green.shade700 : Colors.grey
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final iconPath = Path();
    iconPath.moveTo(position.dx, position.dy - 25);
    iconPath.lineTo(position.dx - 8, position.dy);
    iconPath.moveTo(position.dx, position.dy - 25);
    iconPath.lineTo(position.dx + 8, position.dy);
    iconPath.moveTo(position.dx - 5, position.dy - 10);
    iconPath.lineTo(position.dx + 5, position.dy - 10);
    canvas.drawPath(iconPath, towerPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: anchor.id,
        style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(position.dx - textPainter.width / 2, position.dy + 12));
  }

  void _drawTag(Canvas canvas, Offset position, UwbTag tag) {
    canvas.drawCircle(
        position + const Offset(2, 2),
        12,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(position, 12, Paint()..color = AppTheme.primaryColor);
    canvas.drawCircle(
        position,
        12,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);

    final iconPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(position - const Offset(0, 4), 3, iconPaint);
    canvas.drawLine(position - const Offset(0, 1),
        position + const Offset(0, 5), iconPaint);
    canvas.drawLine(position + const Offset(-4, 1),
        position + const Offset(4, 1), iconPaint);
  }

  void _drawAxisLabels(
      Canvas canvas,
      Size size,
      double minX,
      double maxX,
      double minY,
      double maxY,
      double scale,
      double offsetX,
      double offsetY,
      Offset Function(double, double) toCanvas) {
    final textStyle = TextStyle(
      color: Colors.black87,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.white.withValues(alpha: 0.8),
    );

    double intervalX = 1.0;
    final double rangeX = (maxX - minX).abs();
    if (rangeX > 30) {
      intervalX = 5.0;
    } else if (rangeX > 15) {
      intervalX = 2.0;
    }

    double intervalY = 1.0;
    final double rangeY = (maxY - minY).abs();
    if (rangeY > 30) {
      intervalY = 5.0;
    } else if (rangeY > 15) {
      intervalY = 2.0;
    }

    final double startX = (minX / intervalX).ceilToDouble() * intervalX;
    final double endX = (maxX / intervalX).floorToDouble() * intervalX;
    final double startY = (minY / intervalY).ceilToDouble() * intervalY;
    final double endY = (maxY / intervalY).floorToDouble() * intervalY;

    for (double x = startX; x <= endX; x += intervalX) {
      final pos = toCanvas(x, minY);
      final tp = TextPainter(
        text: TextSpan(text: '${x.toInt()}m', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
          canvas, Offset(pos.dx - tp.width / 2, size.height - offsetY + 8));
    }

    for (double y = startY; y <= endY; y += intervalY) {
      final pos = toCanvas(minX, y);
      final tp = TextPainter(
        text: TextSpan(text: '${y.toInt()}m', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(offsetX - tp.width - 8, pos.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant InspectionCanvasPainter oldDelegate) {
    return oldDelegate.currentTag?.x != currentTag?.x ||
        oldDelegate.currentTag?.y != currentTag?.y ||
        oldDelegate.trajectory.length != trajectory.length ||
        oldDelegate.anchors != anchors ||
        oldDelegate.config != config ||
        oldDelegate.floorPlanImage != floorPlanImage ||
        oldDelegate.pins.length != pins.length ||
        oldDelegate.selectedPinId != selectedPinId ||
        oldDelegate.pins != pins;
  }
}
