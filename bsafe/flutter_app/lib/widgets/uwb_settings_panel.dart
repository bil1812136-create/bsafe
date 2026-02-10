import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bsafe_app/models/uwb_model.dart';
import 'package:bsafe_app/services/uwb_service.dart';
import 'package:bsafe_app/theme/app_theme.dart';

/// UWB 设置面板 - 复制安信可 UWB TWR 应用的设置功能
class UwbSettingsPanel extends StatefulWidget {
  final UwbService uwbService;
  final VoidCallback? onClose;

  const UwbSettingsPanel({
    super.key,
    required this.uwbService,
    this.onClose,
  });

  @override
  State<UwbSettingsPanel> createState() => _UwbSettingsPanelState();
}

class _UwbSettingsPanelState extends State<UwbSettingsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 控制器
  late TextEditingController _gridWidthController;
  late TextEditingController _gridHeightController;
  late TextEditingController _area1Controller;
  late TextEditingController _area2Controller;
  late TextEditingController _correctionAController;
  late TextEditingController _correctionBController;
  late TextEditingController _xOffsetController;
  late TextEditingController _yOffsetController;
  late TextEditingController _xScaleController;
  late TextEditingController _yScaleController;
  late TextEditingController _floorPlanOpacityController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final config = widget.uwbService.config;
    _gridWidthController =
        TextEditingController(text: config.gridWidth.toString());
    _gridHeightController =
        TextEditingController(text: config.gridHeight.toString());
    _area1Controller =
        TextEditingController(text: config.areaRadius1.toString());
    _area2Controller =
        TextEditingController(text: config.areaRadius2.toString());
    _correctionAController =
        TextEditingController(text: config.correctionA.toString());
    _correctionBController =
        TextEditingController(text: config.correctionB.toString());
    _xOffsetController = TextEditingController(text: config.xOffset.toString());
    _yOffsetController = TextEditingController(text: config.yOffset.toString());
    _xScaleController = TextEditingController(text: config.xScale.toString());
    _yScaleController = TextEditingController(text: config.yScale.toString());
    _floorPlanOpacityController =
        TextEditingController(text: config.floorPlanOpacity.toString());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gridWidthController.dispose();
    _gridHeightController.dispose();
    _area1Controller.dispose();
    _area2Controller.dispose();
    _correctionAController.dispose();
    _correctionBController.dispose();
    _xOffsetController.dispose();
    _yOffsetController.dispose();
    _xScaleController.dispose();
    _yScaleController.dispose();
    _floorPlanOpacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: 320,
      height: screenHeight * 0.75, // Use 75% of screen height
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.75,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.settings, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '設置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Tab 栏
          Container(
            color: Colors.grey.shade100,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.primaryColor,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: '功能設置'),
                Tab(text: '平面圖設置'),
                Tab(text: '網格設置'),
                Tab(text: '串口配置'),
              ],
            ),
          ),

          // Tab 内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFunctionSettings(),
                _buildMapSettings(),
                _buildGridSettings(),
                _buildSerialSettings(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 功能设置 Tab
  Widget _buildFunctionSettings() {
    final config = widget.uwbService.config;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 功能选择
          _buildSectionTitle('功能選擇'),
          _buildCheckboxRow('顯示基站列表', config.showAnchorList, (v) {
            _updateConfig(config.copyWith(showAnchorList: v));
          }),
          _buildCheckboxRow('自動獲取基站坐標', config.autoGetAnchorCoords, (v) {
            _updateConfig(config.copyWith(autoGetAnchorCoords: v));
          }),
          _buildCheckboxRow('顯示標籤列表', config.showTagList, (v) {
            _updateConfig(config.copyWith(showTagList: v));
          }),
          _buildCheckboxRow('顯示歷史軌跡', config.showHistoryTrajectory, (v) {
            _updateConfig(config.copyWith(showHistoryTrajectory: v));
          }),
          _buildCheckboxRow('軌跡/導航模式', config.showTrajectory, (v) {
            _updateConfig(config.copyWith(showTrajectory: v));
          }),
          _buildCheckboxRow('區域圍欄模式', config.showFence, (v) {
            _updateConfig(config.copyWith(showFence: v));
          }),

          const SizedBox(height: 16),

          // 区域围栏模式
          _buildSectionTitle('區域圍欄模式'),
          _buildNumberInputRow('區域1 (m)', _area1Controller, (v) {
            _updateConfig(config.copyWith(areaRadius1: v));
          }),
          _buildNumberInputRow('區域2 (m)', _area2Controller, (v) {
            _updateConfig(config.copyWith(areaRadius2: v));
          }),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('外圍報警', style: TextStyle(fontSize: 12)),
                  value: false,
                  groupValue: config.innerFenceAlarm,
                  onChanged: (v) =>
                      _updateConfig(config.copyWith(innerFenceAlarm: v)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('內圍報警', style: TextStyle(fontSize: 12)),
                  value: true,
                  groupValue: config.innerFenceAlarm,
                  onChanged: (v) =>
                      _updateConfig(config.copyWith(innerFenceAlarm: v)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 轨迹/导航模式
          _buildSectionTitle('軌跡/導航模式'),
          _buildDropdownRow('定位模式', config.positioningMode, ['二維定位', '三維定位'],
              (v) {
            _updateConfig(config.copyWith(positioningMode: v));
          }),
          _buildDropdownRow(
              '定位算法', config.algorithm, ['卡爾曼/平均算法', '最小二乘法', '三邊定位'], (v) {
            _updateConfig(config.copyWith(algorithm: v));
          }),

          const SizedBox(height: 16),

          // 距离校正设置
          _buildSectionTitle('距離校正設置'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'y = (${config.correctionA.toStringAsFixed(4)}) * x + (${config.correctionB.toStringAsFixed(2)})',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          _buildNumberInputRow('係數 a', _correctionAController, (v) {
            _updateConfig(config.copyWith(correctionA: v));
          }),
          _buildNumberInputRow('係數 b', _correctionBController, (v) {
            _updateConfig(config.copyWith(correctionB: v));
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: 设置校正系数到设备
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('校正係數已設置')),
                );
              },
              child: const Text('設置校正係數'),
            ),
          ),
        ],
      ),
    );
  }

  // 平面图设置 Tab
  Widget _buildMapSettings() {
    final config = widget.uwbService.config;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('平面地圖'),
          
          // 顯示當前載入的地圖
          if (config.floorPlanImagePath != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已載入地圖',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      widget.uwbService.clearFloorPlan();
                      setState(() {});
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: '清除地圖',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFloorPlanImage,
                  icon: widget.uwbService.isLoadingFloorPlan
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open, size: 16),
                  label: Text(widget.uwbService.isLoadingFloorPlan ? '載入中...' : '打開'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: config.floorPlanImagePath != null
                      ? () {
                          // 保存配置到本地（未來可實現）
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('配置已自動保存')),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('保存'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 顯示/隱藏平面圖
          _buildCheckboxRow('顯示平面圖', config.showFloorPlan, (v) {
            widget.uwbService.toggleFloorPlan(v);
            setState(() {});
          }),
          
          // 透明度調整
          if (config.floorPlanImagePath != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: Text('透明度', style: TextStyle(fontSize: 13)),
                ),
                Expanded(
                  child: Slider(
                    value: config.floorPlanOpacity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    label: '${(config.floorPlanOpacity * 100).toInt()}%',
                    onChanged: (v) {
                      widget.uwbService.updateFloorPlanOpacity(v);
                      _floorPlanOpacityController.text = v.toStringAsFixed(2);
                      setState(() {});
                    },
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${(config.floorPlanOpacity * 100).toInt()}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          _buildSectionTitle('偏移設置'),
          _buildNumberInputRowWithUnit('X 偏移', _xOffsetController, '米', (v) {
            _updateConfig(config.copyWith(xOffset: v));
          }),
          _buildNumberInputRowWithUnit('Y 偏移', _yOffsetController, '米', (v) {
            _updateConfig(config.copyWith(yOffset: v));
          }),
          const SizedBox(height: 16),
          _buildSectionTitle('比例設置'),
          _buildNumberInputRowWithUnit('X 比例', _xScaleController, '像素/米', (v) {
            _updateConfig(config.copyWith(xScale: v));
          }),
          _buildNumberInputRowWithUnit('Y 比例', _yScaleController, '像素/米', (v) {
            _updateConfig(config.copyWith(yScale: v));
          }),
          const SizedBox(height: 16),
          _buildSectionTitle('翻轉設置'),
          _buildCheckboxRow('翻轉 X', config.flipX, (v) {
            _updateConfig(config.copyWith(flipX: v));
          }),
          _buildCheckboxRow('翻轉 Y', config.flipY, (v) {
            _updateConfig(config.copyWith(flipY: v));
          }),
          _buildCheckboxRow('顯示原點', config.showOrigin, (v) {
            _updateConfig(config.copyWith(showOrigin: v));
          }),
          const SizedBox(height: 16),
          
          // 當前檔案格式提示
          if (config.floorPlanImagePath != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '格式：${config.floorPlanFileType.toUpperCase()}  |  ${config.floorPlanImagePath!.split('\\').last.split('/').last}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // 提示說明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '支援的檔案格式：',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• 圖片：PNG, JPG, BMP, GIF, WEBP',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
                const SizedBox(height: 2),
                Text(
                  '• 向量圖：SVG（可調整大小不失真）',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
                const SizedBox(height: 2),
                Text(
                  '• 文件：PDF（自動擷取第一頁）',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
                const SizedBox(height: 2),
                Text(
                  '• 工程圖：DWG/DXF（請先轉換為 PDF 或 SVG）',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
                const SizedBox(height: 6),
                Text(
                  '提示：X/Y比例 = 圖片上每米對應的像素數',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 選擇平面圖檔案（支援多種格式）
  Future<void> _pickFloorPlanImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // 點陣圖格式
          'png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp',
          // 向量圖格式
          'svg',
          // PDF 文件
          'pdf',
          // CAD 工程圖（提示使用者轉檔）
          'dwg', 'dxf',
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        await widget.uwbService.loadFloorPlanImage(filePath);
        
        if (mounted) {
          setState(() {});
          
          final ext = filePath.split('.').last.toLowerCase();
          String formatName;
          switch (ext) {
            case 'svg':
              formatName = 'SVG 向量圖';
              break;
            case 'pdf':
              formatName = 'PDF 文件';
              break;
            case 'dwg':
            case 'dxf':
              // DWG 的錯誤訊息已在 service 中處理
              return;
            default:
              formatName = '${ext.toUpperCase()} 圖片';
          }
          
          if (widget.uwbService.floorPlanImage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$formatName 已載入'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入平面圖失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 网格设置 Tab
  Widget _buildGridSettings() {
    final config = widget.uwbService.config;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('網格參數'),
          _buildNumberInputRowWithUnit('寬度', _gridWidthController, '米', (v) {
            _updateConfig(config.copyWith(gridWidth: v));
          }),
          _buildNumberInputRowWithUnit('高度', _gridHeightController, '米', (v) {
            _updateConfig(config.copyWith(gridHeight: v));
          }),
          const SizedBox(height: 16),
          _buildCheckboxRow('顯示網格', config.showGrid, (v) {
            _updateConfig(config.copyWith(showGrid: v));
          }),
          const SizedBox(height: 24),
          _buildSectionTitle('快捷設置'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickGridButton('0.25m', 0.25),
              _buildQuickGridButton('0.5m', 0.5),
              _buildQuickGridButton('1m', 1.0),
              _buildQuickGridButton('2m', 2.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGridButton(String label, double size) {
    return OutlinedButton(
      onPressed: () {
        _gridWidthController.text = size.toString();
        _gridHeightController.text = size.toString();
        _updateConfig(widget.uwbService.config.copyWith(
          gridWidth: size,
          gridHeight: size,
        ));
      },
      child: Text(label),
    );
  }

  // 串口配置 Tab
  Widget _buildSerialSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('串口配置'),

          // 当前连接状态
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.uwbService.isConnected
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.uwbService.isConnected
                    ? Colors.green.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.uwbService.isConnected
                      ? Icons.check_circle
                      : Icons.info_outline,
                  color: widget.uwbService.isConnected
                      ? Colors.green
                      : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.uwbService.isConnected ? '已連接' : '未連接',
                    style: TextStyle(
                      color: widget.uwbService.isConnected
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 波特率选择
          _buildSectionTitle('波特率'),
          DropdownButtonFormField<int>(
            initialValue: 115200,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]
                .map((rate) => DropdownMenuItem(
                      value: rate,
                      child: Text('$rate'),
                    ))
                .toList(),
            onChanged: (value) {
              // TODO: 更新波特率
            },
          ),

          const SizedBox(height: 16),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 搜索串口 - 会在主界面调用
                    Navigator.pop(context, 'search_ports');
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('搜索串口'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: widget.uwbService.isConnected
                    ? ElevatedButton.icon(
                        onPressed: () {
                          widget.uwbService.disconnect();
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('關閉串口'),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, 'connect');
                        },
                        icon: const Icon(Icons.usb, size: 18),
                        label: const Text('連接串口'),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('提示'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• BU04 設備使用 CH340 或 CP210x 芯片',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  '• 默認波特率為 115200',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  '• 如無法識別請安裝驅動程序',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 辅助方法
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCheckboxRow(String label, bool value, Function(bool) onChanged) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInputRow(String label, TextEditingController controller,
      Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final value = double.tryParse(v);
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInputRowWithUnit(
      String label,
      TextEditingController controller,
      String unit,
      Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final value = double.tryParse(v);
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(unit,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, String value, List<String> options,
      Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: SizedBox(
              height: 32,
              child: DropdownButtonFormField<String>(
                initialValue: value,
                isDense: true,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: OutlineInputBorder(),
                ),
                items: options
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateConfig(UwbConfig config) {
    widget.uwbService.updateConfig(config);
    setState(() {});
  }
}
