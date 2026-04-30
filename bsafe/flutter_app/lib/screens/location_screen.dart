import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:bsafe_app/models/uwb_model.dart';
import 'package:bsafe_app/services/uwb_service.dart';
import 'package:bsafe_app/services/desktop_serial_service_platform.dart';
import 'package:bsafe_app/widgets/uwb_position_canvas.dart';
import 'package:bsafe_app/widgets/uwb_settings_panel.dart';
import 'package:bsafe_app/widgets/uwb_data_tables.dart';
import 'package:bsafe_app/providers/language_provider.dart';
import 'package:bsafe_app/theme/app_theme.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with SingleTickerProviderStateMixin {
  late UwbService _uwbService;
  late TabController _tabController;
  bool _showSettings = false;
  bool _showFullSettings = false; // 显示完整设置面板

  @override
  void initState() {
    super.initState();
    _uwbService = UwbService();
    _uwbService.loadAnchorsFromStorage(); // 从存储加载基站配置
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _uwbService.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();

    return ChangeNotifierProvider.value(
      value: _uwbService,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Header
                  _buildHeader(),

                  // Tab Bar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey.shade700,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(text: language.t('positioning_map')),
                        Tab(text: language.t('data_details')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMapView(),
                        _buildDataView(),
                      ],
                    ),
                  ),
                ],
              ),

              // 错误提示 (只在有错误时显示)
              Consumer<UwbService>(
                builder: (context, uwbService, _) {
                  if (uwbService.lastError == null) return const SizedBox();

                  // 3秒后自动清除错误
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted) {
                      uwbService.clearError();
                    }
                  });

                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      color: Colors.red,
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              uwbService.lastError!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                            onPressed: () => uwbService.clearError(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
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

  Widget _buildHeader() {
    return Consumer<UwbService>(
      builder: (context, uwbService, _) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.wifi_tethering,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UWB Precise Positioning',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: uwbService.isConnected
                                    ? Colors.greenAccent
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              uwbService.isConnected
                                  ? (uwbService.isRealDevice
                                      ? 'BU04 Connected (${uwbService.dataReceiveCount})'
                                      : 'Simulation Mode')
                                  : 'Not Connected',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            // 數據接收指示燈
                            if (uwbService.isConnected &&
                                uwbService.lastDataTime != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: DateTime.now()
                                                .difference(
                                                    uwbService.lastDataTime!)
                                                .inMilliseconds <
                                            500
                                        ? Colors.yellowAccent
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 连接按钮行
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: uwbService.isConnected
                          ? () => uwbService.disconnect()
                          : () => _showConnectDialog(context, uwbService),
                      icon: Icon(
                        uwbService.isConnected ? Icons.stop : Icons.usb,
                        size: 18,
                      ),
                      label: Text(uwbService.isConnected
                          ? 'Disconnect'
                          : 'Connect Device'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: uwbService.isConnected
                            ? Colors.red
                            : AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: uwbService.isConnected
                          ? null
                          : () {
                              uwbService.connect(simulate: true);
                            },
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Simulation Demo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: 0.1),
                        disabledForegroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (uwbService.isConnected && uwbService.currentTag != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCoordItem('X',
                          '${uwbService.currentTag!.x.toStringAsFixed(2)}m'),
                      Container(width: 1, height: 30, color: Colors.white30),
                      _buildCoordItem('Y',
                          '${uwbService.currentTag!.y.toStringAsFixed(2)}m'),
                      Container(width: 1, height: 30, color: Colors.white30),
                      _buildCoordItem('Z',
                          '${uwbService.currentTag!.z.toStringAsFixed(2)}m'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoordItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return Consumer<UwbService>(
      builder: (context, uwbService, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主要内容区域
              Expanded(
                child: Column(
                  children: [
                    // 工具栏
                    Row(
                      children: [
                        // 显示设置按钮
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showSettings = !_showSettings;
                            });
                          },
                          icon: Icon(
                            _showSettings
                                ? Icons.settings
                                : Icons.settings_outlined,
                            color: AppTheme.primaryColor,
                          ),
                          tooltip: 'Quick Settings',
                        ),
                        // 完整设置面板按钮
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showFullSettings = !_showFullSettings;
                            });
                          },
                          icon: Icon(
                            _showFullSettings
                                ? Icons.tune
                                : Icons.tune_outlined,
                            color:
                                _showFullSettings ? Colors.orange : Colors.grey,
                          ),
                          tooltip: 'Full Settings',
                        ),
                        // 清除轨迹
                        IconButton(
                          onPressed: () {
                            uwbService.clearTrajectory();
                          },
                          icon: const Icon(Icons.delete_sweep),
                          color: Colors.orange,
                          tooltip: 'Clear Trajectory',
                        ),
                        const Spacer(),
                        // 基站数量
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cell_tower,
                                  size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Text(
                                '${uwbService.anchors.length} Anchors',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 设置面板 (快捷)
                    if (_showSettings) _buildSettingsPanel(uwbService),

                    const SizedBox(height: 8),

                    // 定位画布
                    Expanded(
                      child: UwbPositionCanvas(
                        anchors: uwbService.anchors,
                        currentTag: uwbService.currentTag,
                        trajectory: uwbService.trajectory,
                        config: uwbService.config,
                        floorPlanImage: uwbService.floorPlanImage,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // 完整设置面板 (右侧)
              if (_showFullSettings) ...[
                const SizedBox(width: 16),
                UwbSettingsPanel(
                  uwbService: uwbService,
                  onClose: () {
                    setState(() {
                      _showFullSettings = false;
                    });
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsPanel(UwbService uwbService) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Display Settings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSwitchTile(
                  'Show Trajectory',
                  Icons.timeline,
                  uwbService.config.showTrajectory,
                  (value) {
                    uwbService.updateConfig(
                      uwbService.config.copyWith(showTrajectory: value),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSwitchTile(
                  'Show Fence',
                  Icons.fence,
                  uwbService.config.showFence,
                  (value) {
                    uwbService.updateConfig(
                      uwbService.config.copyWith(showFence: value),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 围栏半径设置
          if (uwbService.config.showFence) ...[
            Row(
              children: [
                Expanded(
                  child: _buildRadiusSlider(
                    'Inner Fence',
                    uwbService.config.areaRadius1,
                    0.5,
                    5.0,
                    Colors.green,
                    (value) {
                      uwbService.updateConfig(
                        uwbService.config.copyWith(areaRadius1: value),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRadiusSlider(
                    'Outer Fence',
                    uwbService.config.areaRadius2,
                    1.0,
                    10.0,
                    Colors.orange,
                    (value) {
                      uwbService.updateConfig(
                        uwbService.config.copyWith(areaRadius2: value),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
      String title, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20, color: value ? AppTheme.primaryColor : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: value ? AppTheme.primaryColor : Colors.grey.shade700,
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusSlider(String title, double value, double min, double max,
      Color color, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            Text('${value.toStringAsFixed(1)}m',
                style: TextStyle(color: color)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDataView() {
    return Consumer<UwbService>(
      builder: (context, uwbService, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 数据表格区域（类似安信可应用）
              UwbDataPanel(uwbService: uwbService),

              const SizedBox(height: 24),

              // 标签数据卡片
              _buildInfoCard(
                title: 'Tag Data',
                icon: Icons.person_pin_circle,
                child: uwbService.currentTag != null
                    ? Column(
                        children: [
                          _buildDataRow('Tag ID', uwbService.currentTag!.id),
                          const Divider(),
                          _buildDataRow('X Coordinate',
                              '${uwbService.currentTag!.x.toStringAsFixed(3)} m'),
                          const Divider(),
                          _buildDataRow('Y Coordinate',
                              '${uwbService.currentTag!.y.toStringAsFixed(3)} m'),
                          const Divider(),
                          _buildDataRow('Z Coordinate',
                              '${uwbService.currentTag!.z.toStringAsFixed(3)} m'),
                          const Divider(),
                          _buildDataRow('Positioning Accuracy (R95)',
                              '${uwbService.currentTag!.r95.toStringAsFixed(3)} m'),
                        ],
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No Tag Detected',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // 距离数据卡片
              _buildInfoCard(
                title: 'Anchor Distance',
                icon: Icons.radar,
                child: uwbService.currentTag != null &&
                        uwbService.currentTag!.anchorDistances.isNotEmpty
                    ? Column(
                        children: uwbService.currentTag!.anchorDistances.entries
                            .map((e) => Column(
                                  children: [
                                    _buildDataRow(
                                      e.key,
                                      '${e.value.toStringAsFixed(3)} m',
                                      icon: Icons.cell_tower,
                                    ),
                                    if (e.key !=
                                        uwbService.currentTag!.anchorDistances
                                            .keys.last)
                                      const Divider(),
                                  ],
                                ))
                            .toList(),
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No Data',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // 基站配置卡片
              _buildInfoCard(
                title: 'Anchor Configuration',
                icon: Icons.settings_input_antenna,
                child: Column(
                  children: [
                    // 基站列表
                    ...uwbService.anchors.asMap().entries.map((entry) {
                      final index = entry.key;
                      final anchor = entry.value;
                      return Column(
                        children: [
                          _buildAnchorRow(anchor, index, uwbService),
                          if (index < uwbService.anchors.length - 1)
                            const Divider(),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 操作卡片
              _buildInfoCard(
                title: 'Operations',
                icon: Icons.tune,
                child: Column(
                  children: [
                    _buildActionButton(
                      icon: Icons.refresh,
                      label: 'Reset Anchor Configuration',
                      color: AppTheme.primaryColor,
                      onTap: () {
                        uwbService.initializeDefaultAnchors();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Anchor configuration reset')),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.delete_sweep,
                      label: 'Clear Trajectory Records',
                      color: Colors.orange,
                      onTap: () {
                        uwbService.clearTrajectory();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Trajectory cleared')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 提示信息
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This feature uses UWB ultra-wideband positioning technology to provide centimeter-level precise positioning in indoor environments for location tracking during building safety inspections.',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnchorRow(UwbAnchor anchor, int index, UwbService uwbService) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  anchor.isActive ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.cell_tower,
              color: anchor.isActive ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anchor.id,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '(${anchor.x}, ${anchor.y}, ${anchor.z})',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            color: Colors.grey,
            onPressed: () =>
                _showEditAnchorDialog(context, anchor, index, uwbService),
          ),
        ],
      ),
    );
  }

  void _showEditAnchorDialog(BuildContext context, UwbAnchor anchor, int index,
      UwbService uwbService) {
    final xController = TextEditingController(text: anchor.x.toString());
    final yController = TextEditingController(text: anchor.y.toString());
    final zController = TextEditingController(text: anchor.z.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${anchor.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: xController,
              decoration: const InputDecoration(labelText: 'X Coordinate (m)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: yController,
              decoration: const InputDecoration(labelText: 'Y Coordinate (m)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: zController,
              decoration:
                  const InputDecoration(labelText: 'Z Coordinate/Height (m)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newAnchor = UwbAnchor(
                id: anchor.id,
                x: double.tryParse(xController.text) ?? anchor.x,
                y: double.tryParse(yController.text) ?? anchor.y,
                z: double.tryParse(zController.text) ?? anchor.z,
                isActive: anchor.isActive,
              );
              uwbService.updateAnchor(index, newAnchor);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  // 显示连接对话框
  void _showConnectDialog(BuildContext context, UwbService uwbService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(Icons.usb, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Connect UWB Device',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 连接选项
            _buildConnectOption(
              icon: Icons.wifi_tethering,
              title: 'Auto-Connect BU04',
              subtitle: 'Auto-connect Anxin UWB device via USB serial port',
              color: AppTheme.primaryColor,
              onTap: () async {
                Navigator.pop(context);
                _showSerialConnectDialog(context, uwbService);
              },
            ),
            const SizedBox(height: 12),

            _buildConnectOption(
              icon: Icons.edit_location_alt,
              title: 'Manual Coordinate Entry',
              subtitle: 'Manually enter X, Y, Z coordinates of BU04 tag',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showManualInputDialog(context, uwbService);
              },
            ),
            const SizedBox(height: 12),

            _buildConnectOption(
              icon: Icons.play_circle_outline,
              title: 'Simulation Demo Mode',
              subtitle: 'Demonstrate UWB positioning with simulated data',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                uwbService.connect(simulate: true);
              },
            ),

            const SizedBox(height: 20),

            // 提示
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
                      'Ensure BU04 is connected to your computer via USB and the appropriate drivers are installed.',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
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

  // 串口连接对话框 - 显示可选择的串口列表
  void _showSerialConnectDialog(BuildContext context, UwbService uwbService) {
    // 检查平台
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'On web platform, use browser serial port selection feature'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 获取可用串口列表
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
              Text('No Serial Port Found'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No serial port devices detected.'),
              SizedBox(height: 12),
              Text('Please confirm:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• BU04 device is connected via USB'),
              Text('• CH340 or CP210x driver is installed'),
              Text('• Device shows normal in Device Manager'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Confirm'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // 重新检测
                _showSerialConnectDialog(context, uwbService);
              },
              child: const Text('Re-detect'),
            ),
          ],
        ),
      );
      return;
    }

    // 显示串口选择对话框
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(Icons.usb, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Select Serial Port',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // 刷新按钮
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showSerialConnectDialog(context, uwbService);
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Serial Port List',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),

            // 串口数量提示
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Found ${ports.length} serial port devices',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),

            // 串口列表
            ...ports.map((port) => _buildPortItem(
                  context,
                  port: port,
                  uwbService: uwbService,
                )),

            const SizedBox(height: 16),

            // 提示
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
                      'If multiple BU04 units are connected, select the corresponding device based on the port number in Device Manager.',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }

  // 构建串口选项
  Widget _buildPortItem(
    BuildContext context, {
    required String port,
    required UwbService uwbService,
  }) {
    // 解析端口信息
    final String portName = port;
    String portDescription = 'Serial Port Device';

    // 尝试识别常见设备
    if (port.contains('COM')) {
      portDescription = 'Windows Serial Port';
    } else if (port.contains('ttyUSB')) {
      portDescription = 'Linux USB Serial Port';
    } else if (port.contains('ttyACM')) {
      portDescription = 'Linux ACM Serial Port';
    } else if (port.contains('cu.')) {
      portDescription = 'macOS Serial Port';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          Navigator.pop(context);
          await _connectToPort(context, uwbService, port);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border:
                Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.usb,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      portName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      portDescription,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 连接到指定串口
  Future<void> _connectToPort(
    BuildContext context,
    UwbService uwbService,
    String portName,
  ) async {
    // 显示连接中对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.usb, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('Connect $portName'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Connecting to $portName...'),
            const SizedBox(height: 8),
            Text(
              'Baud Rate: 115200',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    // 尝试连接指定端口
    final success = await uwbService.connectToPort(portName);

    // 关闭对话框
    if (context.mounted) Navigator.pop(context);

    if (success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully connected to $portName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(uwbService.lastError ?? 'Failed to connect to $portName'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 手动输入对话框
  void _showManualInputDialog(BuildContext context, UwbService uwbService) {
    final xController = TextEditingController(text: '4.533');
    final yController = TextEditingController(text: '1.868');
    final zController = TextEditingController(text: '0.0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_location, color: Colors.orange),
            SizedBox(width: 8),
            Text('Manual Coordinate Entry'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: xController,
              decoration: const InputDecoration(
                labelText: 'X Coordinate (meters)',
                hintText: 'E.g.: 4.533',
                prefixIcon: Icon(Icons.arrow_right),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: yController,
              decoration: const InputDecoration(
                labelText: 'Y Coordinate (meters)',
                hintText: 'E.g.: 1.868',
                prefixIcon: Icon(Icons.arrow_upward),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: zController,
              decoration: const InputDecoration(
                labelText: 'Z Coordinate (meters)',
                hintText: 'E.g.: 0.0',
                prefixIcon: Icon(Icons.height),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enter coordinate values read from BU04 device',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final x = double.tryParse(xController.text);
              final y = double.tryParse(yController.text);
              final z = double.tryParse(zController.text) ?? 0.0;

              if (x != null && y != null) {
                // 使用手动输入的坐标
                final dataStr = '$x,$y,$z';
                uwbService.processSerialData(dataStr);

                // 标记为已连接（手动模式）
                if (!uwbService.isConnected) {
                  uwbService.connect(simulate: false);
                  uwbService.stopSimulation();
                }

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Location updated: X=$x, Y=$y, Z=$z'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid coordinate values'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
