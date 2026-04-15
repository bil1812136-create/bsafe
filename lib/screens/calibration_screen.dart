import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bsafe_app/models/uwb_model.dart';
import 'package:bsafe_app/services/uwb_service.dart';
import 'package:bsafe_app/theme/app_theme.dart';

/// 校正模式：平面圖上點擊放置基站，輸入距離自動計算座標
class CalibrationScreen extends StatefulWidget {
  final UwbService uwbService;

  const CalibrationScreen({super.key, required this.uwbService});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  // 模式：floor_plan 或 room_dimension
  String _mode = 'choose'; // choose, floor_plan, room_dimension

  // 房間尺寸
  final _roomWidthController = TextEditingController(text: '4.85');
  final _roomHeightController = TextEditingController(text: '5.44');
  double _roomWidth = 4.85;
  double _roomHeight = 5.44;

  // 平面圖
  ui.Image? _floorPlanImage;
  String? _floorPlanPath;

  // 放置的基站 (像素座標)
  final List<_CalibrationAnchor> _placedAnchors = [];

  // 距離配對
  final List<_DistancePair> _distancePairs = [];

  // 基站高度 (統一)
  double _anchorHeight = 3.0;

  // 選中的基站 index（用於設定距離）
  int? _selectedAnchorIndex;
  int? _secondAnchorIndex;

  // 校正結果
  double? _calculatedScale; // 米/像素
  bool _isCalibrated = false;

  // 互動鍵
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void dispose() {
    _roomWidthController.dispose();
    _roomHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('基站校正設置'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_mode != 'choose')
            TextButton.icon(
              onPressed: _resetCalibration,
              icon: const Icon(Icons.refresh, color: Colors.white70),
              label: const Text('重置', style: TextStyle(color: Colors.white70)),
            ),
          if (_isCalibrated)
            ElevatedButton.icon(
              onPressed: _applyCalibration,
              icon: const Icon(Icons.check),
              label: const Text('應用'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _mode == 'choose' ? _buildModeChooser() : _buildCalibrationView(),
    );
  }

  // ===== 選擇模式 =====
  Widget _buildModeChooser() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.tune, size: 64, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const Text(
                '選擇校正方式',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '在平面圖或房間示意圖上點擊放置基站，輸入基站間距離即可自動計算座標',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              // 方式一：載入平面圖
              _buildModeCard(
                icon: Icons.image,
                title: '載入平面圖',
                subtitle: '載入樓層平面圖 (PNG/JPG/PDF)，在圖上點擊放置基站',
                color: AppTheme.primaryColor,
                onTap: () => _pickFloorPlan(),
              ),

              const SizedBox(height: 16),

              // 方式二：輸入房間尺寸
              _buildModeCard(
                icon: Icons.square_foot,
                title: '輸入房間大小',
                subtitle: '輸入房間長寬（米），自動生成房間示意圖',
                color: Colors.teal,
                onTap: () => _showRoomDimensionDialog(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: isMobile ? 28 : 36, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: Colors.grey.shade400, size: isMobile ? 16 : 20),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 校正主視圖 =====
  Widget _buildCalibrationView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      return _buildMobileCalibrationView();
    }

    return Row(
      children: [
        // 左側：畫布
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // 工具欄
              _buildToolBar(),
              // 畫布
              Expanded(
                child: Container(
                  color: Colors.grey.shade200,
                  child: ClipRect(
                    child: GestureDetector(
                      onTapDown: _handleCanvasTap,
                      child: CustomPaint(
                        key: _canvasKey,
                        painter: _CalibrationPainter(
                          mode: _mode,
                          floorPlanImage: _floorPlanImage,
                          roomWidth: _roomWidth,
                          roomHeight: _roomHeight,
                          anchors: _placedAnchors,
                          distancePairs: _distancePairs,
                          selectedIndex: _selectedAnchorIndex,
                          secondIndex: _secondAnchorIndex,
                          calculatedScale: _calculatedScale,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 右側：設定面板
        SizedBox(
          width: 320,
          child: _buildSidePanel(),
        ),
      ],
    );
  }

  // ===== 手機版校正視圖 =====
  Widget _buildMobileCalibrationView() {
    return Column(
      children: [
        // 簡化工具欄
        _buildMobileToolBar(),
        // 畫布（佔上半部分）
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.grey.shade200,
            child: ClipRect(
              child: GestureDetector(
                onTapDown: _handleCanvasTap,
                child: CustomPaint(
                  key: _canvasKey,
                  painter: _CalibrationPainter(
                    mode: _mode,
                    floorPlanImage: _floorPlanImage,
                    roomWidth: _roomWidth,
                    roomHeight: _roomHeight,
                    anchors: _placedAnchors,
                    distancePairs: _distancePairs,
                    selectedIndex: _selectedAnchorIndex,
                    secondIndex: _secondAnchorIndex,
                    calculatedScale: _calculatedScale,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        // 底部設定面板（可滑動）
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 拖動指示器
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 滾動內容
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 基站高度
                        _buildHeightSetting(),
                        const Divider(height: 24),

                        // 已放置的基站列表
                        _buildAnchorList(),
                        const Divider(height: 24),

                        // 距離設定
                        _buildDistanceSection(),
                        const Divider(height: 24),

                        // 校正結果
                        if (_isCalibrated) _buildCalibrationResult(),

                        // 操作提示
                        _buildInstructions(),
                        const SizedBox(height: 20),
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

  // ===== 手機版工具欄 =====
  Widget _buildMobileToolBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Icon(
            _mode == 'floor_plan' ? Icons.image : Icons.square_foot,
            size: 18,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _mode == 'floor_plan' ? '平面圖校正' : '$_roomWidth×${_roomHeight}m',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '已放 ${_placedAnchors.length} 個基站',
              style: TextStyle(color: Colors.blue.shade700, fontSize: 11),
            ),
          ),
          if (_isCalibrated) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 14),
                  SizedBox(width: 2),
                  Text('已校正',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== 工具欄 =====
  Widget _buildToolBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Icon(
            _mode == 'floor_plan' ? Icons.image : Icons.square_foot,
            size: 20,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            _mode == 'floor_plan'
                ? '平面圖校正'
                : '房間尺寸校正 ($_roomWidth × $_roomHeight m)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '點擊畫布放置基站 (已放 ${_placedAnchors.length} 個)',
              style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
            ),
          ),
          if (_isCalibrated) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '已校正',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== 右側面板 =====
  Widget _buildSidePanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
            ),
            child: const Row(
              children: [
                Icon(Icons.cell_tower, color: Colors.white),
                SizedBox(width: 8),
                Text('基站設置',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 基站高度
                  _buildHeightSetting(),
                  const Divider(height: 24),

                  // 已放置的基站列表
                  _buildAnchorList(),
                  const Divider(height: 24),

                  // 距離設定
                  _buildDistanceSection(),
                  const Divider(height: 24),

                  // 校正結果
                  if (_isCalibrated) _buildCalibrationResult(),

                  // 操作提示
                  _buildInstructions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 統一高度設定 =====
  Widget _buildHeightSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('基站高度 (統一)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _anchorHeight.toString(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: '米',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final h = double.tryParse(v);
                  if (h != null && h > 0) {
                    setState(() => _anchorHeight = h);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Text('(天花板高度)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  // ===== 基站列表 =====
  Widget _buildAnchorList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('已放置基站',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text('${_placedAnchors.length} 個',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        if (_placedAnchors.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                '點擊畫布放置基站',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ..._placedAnchors.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            final isSelected = i == _selectedAnchorIndex;
            final isSecond = i == _secondAnchorIndex;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.shade50
                    : isSecond
                        ? Colors.orange.shade50
                        : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.blue
                      : isSecond
                          ? Colors.orange
                          : Colors.grey.shade200,
                  width: isSelected || isSecond ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _getAnchorColor(i),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        if (_isCalibrated && a.realX != null && a.realY != null)
                          Text(
                            '(${a.realX!.toStringAsFixed(2)}, ${a.realY!.toStringAsFixed(2)}) m',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontFamily: 'monospace'),
                          )
                        else
                          Text(
                            '像素: (${a.pixelX.toInt()}, ${a.pixelY.toInt()})',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  // 選擇用於距離對
                  InkWell(
                    onTap: () => _selectAnchorForDistance(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected || isSecond
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.straighten, size: 16),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _removeAnchor(i),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.close,
                          size: 16, color: Colors.red.shade400),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ===== 距離設定區 =====
  Widget _buildDistanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('基站間距離',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            if (_placedAnchors.length >= 2)
              TextButton.icon(
                onPressed: _addDistancePair,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加距離', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '選擇兩個基站並輸入實際距離（米）',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        if (_distancePairs.isEmpty && _placedAnchors.length >= 2)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '需要至少一組距離來計算比例尺',
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
        ..._distancePairs.asMap().entries.map((entry) {
          final i = entry.key;
          final pair = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: _getAnchorColor(pair.anchorA),
                      child: Text('${pair.anchorA + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.swap_horiz, size: 16),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: _getAnchorColor(pair.anchorB),
                      child: Text('${pair.anchorB + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextFormField(
                          initialValue:
                              pair.distance > 0 ? pair.distance.toString() : '',
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            suffixText: '米',
                            hintText: '距離',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) {
                            final d = double.tryParse(v);
                            if (d != null && d > 0) {
                              setState(() {
                                _distancePairs[i] = _DistancePair(
                                    pair.anchorA, pair.anchorB, d,
                                    pixelDistance: pair.pixelDistance);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _distancePairs.removeAt(i);
                          _recalculate();
                        });
                      },
                      child: Icon(Icons.close,
                          size: 16, color: Colors.red.shade400),
                    ),
                  ],
                ),
                if (pair.pixelDistance > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '像素距離: ${pair.pixelDistance.toStringAsFixed(1)} px',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
              ],
            ),
          );
        }),
        if (_distancePairs.isNotEmpty &&
            _distancePairs.any((d) => d.distance > 0))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _recalculate,
                icon: const Icon(Icons.calculate, size: 18),
                label: const Text('計算校正'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ===== 校正結果 =====
  Widget _buildCalibrationResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('校正完成',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              Text('比例尺: ${_calculatedScale!.toStringAsFixed(4)} 米/像素',
                  style:
                      const TextStyle(fontSize: 13, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              const Text('基站座標:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ..._placedAnchors
                  .where((a) => a.realX != null)
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '  ${a.name}: (${a.realX!.toStringAsFixed(2)}, ${a.realY!.toStringAsFixed(2)}, ${_anchorHeight.toStringAsFixed(1)})',
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'monospace'),
                        ),
                      )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _applyCalibration,
            icon: const Icon(Icons.check),
            label: const Text('應用到系統'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  // ===== 操作說明 =====
  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('操作步驟:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.blue.shade800)),
          const SizedBox(height: 8),
          _buildStep(1, '在畫布上點擊放置基站（至少 2 個）', _placedAnchors.length >= 2),
          _buildStep(2, '點擊 📏 按鈕選擇基站對', _selectedAnchorIndex != null),
          _buildStep(
              3, '輸入基站間的實際距離（米）', _distancePairs.any((d) => d.distance > 0)),
          _buildStep(4, '點擊「計算校正」', _isCalibrated),
          _buildStep(5, '點擊「應用到系統」完成', false),
        ],
      ),
    );
  }

  Widget _buildStep(int num, String text, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: done ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$num. $text',
              style: TextStyle(
                fontSize: 12,
                color: done ? Colors.green.shade700 : Colors.grey.shade700,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 事件處理 =====

  Future<void> _pickFloorPlan() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'bmp'],
      dialogTitle: '選擇平面圖',
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      try {
        final file = File(path);
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        setState(() {
          _floorPlanImage = frame.image;
          _floorPlanPath = path;
          _mode = 'floor_plan';
          _placedAnchors.clear();
          _distancePairs.clear();
          _isCalibrated = false;
          _calculatedScale = null;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('載入平面圖失敗: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showRoomDimensionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.square_foot, color: Colors.teal),
            SizedBox(width: 8),
            Text('輸入房間大小'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _roomWidthController,
              decoration: const InputDecoration(
                labelText: '房間寬度',
                suffixText: '米',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roomHeightController,
              decoration: const InputDecoration(
                labelText: '房間長度',
                suffixText: '米',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Text(
              '提示：基站通常安裝在房間四個角落的天花板',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final w = double.tryParse(_roomWidthController.text);
              final h = double.tryParse(_roomHeightController.text);
              if (w != null && h != null && w > 0 && h > 0) {
                setState(() {
                  _roomWidth = w;
                  _roomHeight = h;
                  _mode = 'room_dimension';
                  _placedAnchors.clear();
                  _distancePairs.clear();
                  _isCalibrated = false;
                  _calculatedScale = null;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  void _handleCanvasTap(TapDownDetails details) {
    final RenderBox? box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = details.localPosition;
    final size = box.size;

    if (_mode == 'room_dimension') {
      // 房間模式：直接將像素轉換為米
      const padding = 60.0;
      final drawWidth = size.width - padding * 2;
      final drawHeight = size.height - padding * 2;
      final scaleX = drawWidth / _roomWidth;
      final scaleY = drawHeight / _roomHeight;
      final scale = min(scaleX, scaleY);
      final ox = (size.width - _roomWidth * scale) / 2;
      final oy = (size.height - _roomHeight * scale) / 2;

      // 檢查是否在房間內
      final px = localPosition.dx;
      final py = localPosition.dy;
      if (px >= ox &&
          px <= ox + _roomWidth * scale &&
          py >= oy &&
          py <= oy + _roomHeight * scale) {
        // 轉換為米座標
        final realX = (px - ox) / scale;
        final realY = _roomHeight - (py - oy) / scale; // Y軸翻轉

        setState(() {
          _placedAnchors.add(_CalibrationAnchor(
            name: '基站${_placedAnchors.length}',
            pixelX: px,
            pixelY: py,
            realX: realX,
            realY: realY,
          ));
          _isCalibrated = false;
          // 房間模式下自動更新距離對的像素距離
          _updatePixelDistances();
          // 房間模式直接有座標，檢查是否能自動校正
          _autoCalibRoomMode();
        });
      }
    } else if (_mode == 'floor_plan') {
      // 平面圖模式：記錄像素座標
      setState(() {
        _placedAnchors.add(_CalibrationAnchor(
          name: '基站${_placedAnchors.length}',
          pixelX: localPosition.dx,
          pixelY: localPosition.dy,
        ));
        _isCalibrated = false;
        _updatePixelDistances();
      });
    }
  }

  void _selectAnchorForDistance(int index) {
    setState(() {
      if (_selectedAnchorIndex == null) {
        _selectedAnchorIndex = index;
        _secondAnchorIndex = null;
      } else if (_selectedAnchorIndex == index) {
        _selectedAnchorIndex = null;
        _secondAnchorIndex = null;
      } else {
        _secondAnchorIndex = index;
        // 自動添加距離對
        _addDistancePairFromSelection();
        _selectedAnchorIndex = null;
        _secondAnchorIndex = null;
      }
    });
  }

  void _addDistancePairFromSelection() {
    if (_selectedAnchorIndex == null || _secondAnchorIndex == null) return;
    final a = _selectedAnchorIndex!;
    final b = _secondAnchorIndex!;

    // 檢查這對是否已存在
    final exists = _distancePairs.any((p) =>
        (p.anchorA == a && p.anchorB == b) ||
        (p.anchorA == b && p.anchorB == a));
    if (exists) return;

    final pixDist = _pixelDistance(a, b);
    setState(() {
      _distancePairs.add(_DistancePair(a, b, 0, pixelDistance: pixDist));
    });
  }

  void _addDistancePair() {
    if (_placedAnchors.length < 2) return;
    // 找一對尚未添加的
    for (int i = 0; i < _placedAnchors.length; i++) {
      for (int j = i + 1; j < _placedAnchors.length; j++) {
        final exists = _distancePairs.any((p) =>
            (p.anchorA == i && p.anchorB == j) ||
            (p.anchorA == j && p.anchorB == i));
        if (!exists) {
          final pixDist = _pixelDistance(i, j);
          setState(() {
            _distancePairs.add(_DistancePair(i, j, 0, pixelDistance: pixDist));
          });
          return;
        }
      }
    }
    // 全都加了
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有基站對的距離已添加')),
      );
    }
  }

  void _removeAnchor(int index) {
    setState(() {
      _placedAnchors.removeAt(index);
      // 更新距離對的引用
      _distancePairs
          .removeWhere((p) => p.anchorA == index || p.anchorB == index);
      for (int i = 0; i < _distancePairs.length; i++) {
        final p = _distancePairs[i];
        _distancePairs[i] = _DistancePair(
          p.anchorA > index ? p.anchorA - 1 : p.anchorA,
          p.anchorB > index ? p.anchorB - 1 : p.anchorB,
          p.distance,
          pixelDistance: p.pixelDistance,
        );
      }
      _isCalibrated = false;
      _calculatedScale = null;
    });
  }

  double _pixelDistance(int a, int b) {
    final ax = _placedAnchors[a].pixelX;
    final ay = _placedAnchors[a].pixelY;
    final bx = _placedAnchors[b].pixelX;
    final by = _placedAnchors[b].pixelY;
    return sqrt(pow(ax - bx, 2) + pow(ay - by, 2));
  }

  void _updatePixelDistances() {
    for (int i = 0; i < _distancePairs.length; i++) {
      final p = _distancePairs[i];
      if (p.anchorA < _placedAnchors.length &&
          p.anchorB < _placedAnchors.length) {
        _distancePairs[i] = _DistancePair(p.anchorA, p.anchorB, p.distance,
            pixelDistance: _pixelDistance(p.anchorA, p.anchorB));
      }
    }
  }

  void _autoCalibRoomMode() {
    // 房間模式已有真實座標，不需要距離校正
    if (_mode == 'room_dimension' && _placedAnchors.length >= 2) {
      setState(() {
        _calculatedScale = 1.0; // 房間模式比例尺已內含
        _isCalibrated = true;
      });
    }
  }

  void _recalculate() {
    if (_mode == 'room_dimension') {
      _autoCalibRoomMode();
      return;
    }

    // 平面圖模式：用距離對計算比例尺
    final validPairs = _distancePairs.where((p) => p.distance > 0).toList();
    if (validPairs.isEmpty) return;

    // 先確保 pixelDistance 已更新
    _updatePixelDistances();

    // 計算平均比例尺
    double totalScale = 0;
    int count = 0;
    for (final pair in validPairs) {
      // 重新計算像素距離以確保準確
      final pixDist = (pair.anchorA < _placedAnchors.length &&
              pair.anchorB < _placedAnchors.length)
          ? _pixelDistance(pair.anchorA, pair.anchorB)
          : pair.pixelDistance;
      if (pixDist > 0) {
        totalScale += pair.distance / pixDist; // 米/像素
        count++;
      }
    }
    if (count == 0) return;

    final avgScale = totalScale / count;

    // 用第一個基站作為原點，計算所有基站的真實座標
    final originX = _placedAnchors[0].pixelX;
    final originY = _placedAnchors[0].pixelY;

    setState(() {
      _calculatedScale = avgScale;
      for (int i = 0; i < _placedAnchors.length; i++) {
        final a = _placedAnchors[i];
        _placedAnchors[i] = _CalibrationAnchor(
          name: a.name,
          pixelX: a.pixelX,
          pixelY: a.pixelY,
          realX: (a.pixelX - originX) * avgScale,
          realY: -(a.pixelY - originY) * avgScale, // Y軸翻轉
        );
      }
      _isCalibrated = true;
    });
  }

  void _resetCalibration() {
    setState(() {
      _placedAnchors.clear();
      _distancePairs.clear();
      _isCalibrated = false;
      _calculatedScale = null;
      _selectedAnchorIndex = null;
      _secondAnchorIndex = null;
      _mode = 'choose';
      _floorPlanImage = null;
      _floorPlanPath = null;
    });
  }

  void _applyCalibration() {
    if (!_isCalibrated || _placedAnchors.isEmpty) return;

    final uwb = widget.uwbService;

    // 清除現有基站
    while (uwb.anchors.isNotEmpty) {
      uwb.removeAnchor(0);
    }

    // 添加校正後的基站
    for (final a in _placedAnchors) {
      final x = a.realX ?? 0.0;
      final y = a.realY ?? 0.0;
      uwb.addAnchor(UwbAnchor(
        id: a.name,
        x: x,
        y: y,
        z: _anchorHeight,
        isActive: true,
      ));
    }

    // 如果有平面圖，也設置 floor plan 的比例尺和偏移
    if (_mode == 'floor_plan' &&
        _floorPlanPath != null &&
        _calculatedScale != null &&
        _floorPlanImage != null) {
      final img = _floorPlanImage!;
      final imgWidth = img.width.toDouble();
      final imgHeight = img.height.toDouble();

      // 取得畫布尺寸，計算校正畫面中圖片的顯示變換
      final RenderBox? box =
          _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final widgetSize = box.size;
        // 與 _CalibrationPainter._drawFloorPlan 相同的變換
        final scaleX = widgetSize.width / imgWidth;
        final scaleY = widgetSize.height / imgHeight;
        final displayScale = min(scaleX, scaleY) * 0.9;
        final ox = (widgetSize.width - imgWidth * displayScale) / 2;
        final oy = (widgetSize.height - imgHeight * displayScale) / 2;

        // 將原點基站從 widget 座標轉換為實際圖片像素座標
        final originImageX =
            (_placedAnchors[0].pixelX - ox) / displayScale;
        final originImageY =
            (_placedAnchors[0].pixelY - oy) / displayScale;

        // 計算圖片像素的比例尺
        // _calculatedScale = 米/widget像素
        // 圖片像素 = widget像素 / displayScale
        // 米/圖片像素 = _calculatedScale * displayScale
        final metersPerImagePixel = _calculatedScale! * displayScale;
        final pixelsPerMeter = 1.0 / metersPerImagePixel;

        // 平面圖偏移：圖片邊緣在 UWB 座標系中的位置
        // 圖片左邊 (X=0) 的真實座標
        final offsetX = -originImageX * metersPerImagePixel;
        // 圖片底邊 (Y=imgHeight) 的真實座標
        final offsetY =
            -(imgHeight - originImageY) * metersPerImagePixel;

        uwb.updateConfig(uwb.config.copyWith(
          xScale: pixelsPerMeter,
          yScale: pixelsPerMeter,
          xOffset: offsetX,
          yOffset: offsetY,
          flipX: false,
          flipY: false,
        ));
      }

      // 載入平面圖
      uwb.loadFloorPlanImage(_floorPlanPath!);
    } else if (_mode == 'room_dimension') {
      // 房間模式，不需要平面圖
      uwb.updateConfig(uwb.config.copyWith(
        showFloorPlan: false,
      ));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 已應用校正：${_placedAnchors.length} 個基站'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Color _getAnchorColor(int index) {
    const colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal
    ];
    return colors[index % colors.length];
  }
}

// ===== 校正資料模型 =====
class _CalibrationAnchor {
  final String name;
  final double pixelX;
  final double pixelY;
  final double? realX; // 真實座標 (米)
  final double? realY;

  _CalibrationAnchor({
    required this.name,
    required this.pixelX,
    required this.pixelY,
    this.realX,
    this.realY,
  });
}

class _DistancePair {
  final int anchorA;
  final int anchorB;
  final double distance; // 實際距離 (米)
  final double pixelDistance; // 像素距離

  _DistancePair(this.anchorA, this.anchorB, this.distance,
      {this.pixelDistance = 0});
}

// ===== 校正畫布 Painter =====
class _CalibrationPainter extends CustomPainter {
  final String mode;
  final ui.Image? floorPlanImage;
  final double roomWidth;
  final double roomHeight;
  final List<_CalibrationAnchor> anchors;
  final List<_DistancePair> distancePairs;
  final int? selectedIndex;
  final int? secondIndex;
  final double? calculatedScale;

  _CalibrationPainter({
    required this.mode,
    this.floorPlanImage,
    required this.roomWidth,
    required this.roomHeight,
    required this.anchors,
    required this.distancePairs,
    this.selectedIndex,
    this.secondIndex,
    this.calculatedScale,
  });

  static const _anchorColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == 'room_dimension') {
      _drawRoom(canvas, size);
    } else if (mode == 'floor_plan') {
      _drawFloorPlan(canvas, size);
    }

    // 繪製距離線
    _drawDistanceLines(canvas, size);

    // 繪製基站
    for (int i = 0; i < anchors.length; i++) {
      _drawAnchor(canvas, anchors[i], i);
    }
  }

  void _drawRoom(Canvas canvas, Size size) {
    const padding = 60.0;
    final drawWidth = size.width - padding * 2;
    final drawHeight = size.height - padding * 2;
    final scaleX = drawWidth / roomWidth;
    final scaleY = drawHeight / roomHeight;
    final scale = min(scaleX, scaleY);
    final ox = (size.width - roomWidth * scale) / 2;
    final oy = (size.height - roomHeight * scale) / 2;

    // 房間背景
    final roomRect =
        Rect.fromLTWH(ox, oy, roomWidth * scale, roomHeight * scale);
    canvas.drawRect(roomRect, Paint()..color = Colors.white);
    canvas.drawRect(
      roomRect,
      Paint()
        ..color = Colors.grey.shade800
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // 網格線 (每米)
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;
    for (double x = 0; x <= roomWidth; x += 1.0) {
      canvas.drawLine(
        Offset(ox + x * scale, oy),
        Offset(ox + x * scale, oy + roomHeight * scale),
        gridPaint,
      );
    }
    for (double y = 0; y <= roomHeight; y += 1.0) {
      canvas.drawLine(
        Offset(ox, oy + y * scale),
        Offset(ox + roomWidth * scale, oy + y * scale),
        gridPaint,
      );
    }

    // 尺寸標註 - 底邊 (寬度)
    _drawDimensionLabel(
        canvas,
        Offset(ox, oy + roomHeight * scale + 20),
        Offset(ox + roomWidth * scale, oy + roomHeight * scale + 20),
        '${roomWidth}m');

    // 尺寸標註 - 右邊 (長度)
    _drawDimensionLabel(
        canvas,
        Offset(ox + roomWidth * scale + 20, oy),
        Offset(ox + roomWidth * scale + 20, oy + roomHeight * scale),
        '${roomHeight}m',
        vertical: true);

    // 角落標註坐標
    _drawCornerLabel(canvas, Offset(ox, oy + roomHeight * scale), '(0, 0)');
    _drawCornerLabel(
        canvas,
        Offset(ox + roomWidth * scale, oy + roomHeight * scale),
        '($roomWidth, 0)');
    _drawCornerLabel(canvas, Offset(ox, oy), '(0, $roomHeight)');
    _drawCornerLabel(canvas, Offset(ox + roomWidth * scale, oy),
        '($roomWidth, $roomHeight)');
  }

  void _drawCornerLabel(Canvas canvas, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + 4));
  }

  void _drawDimensionLabel(Canvas canvas, Offset start, Offset end, String text,
      {bool vertical = false}) {
    final paint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1;

    canvas.drawLine(start, end, paint);

    // 箭頭
    if (!vertical) {
      canvas.drawLine(start, start + const Offset(8, -4), paint);
      canvas.drawLine(start, start + const Offset(8, 4), paint);
      canvas.drawLine(end, end + const Offset(-8, -4), paint);
      canvas.drawLine(end, end + const Offset(-8, 4), paint);
    }

    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 13,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    if (vertical) {
      canvas.save();
      canvas.translate(mid.dx + 10, mid.dy);
      canvas.rotate(-pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, 0));
      canvas.restore();
    } else {
      tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy + 4));
    }
  }

  void _drawFloorPlan(Canvas canvas, Size size) {
    if (floorPlanImage == null) return;

    final img = floorPlanImage!;
    final imgWidth = img.width.toDouble();
    final imgHeight = img.height.toDouble();

    // 縮放將圖片適配到畫布
    final scaleX = size.width / imgWidth;
    final scaleY = size.height / imgHeight;
    final scale = min(scaleX, scaleY) * 0.9;
    final ox = (size.width - imgWidth * scale) / 2;
    final oy = (size.height - imgHeight * scale) / 2;

    final srcRect = Rect.fromLTWH(0, 0, imgWidth, imgHeight);
    final dstRect = Rect.fromLTWH(ox, oy, imgWidth * scale, imgHeight * scale);

    // 背景
    canvas.drawRect(dstRect, Paint()..color = Colors.white);

    // 圖片
    canvas.drawImageRect(
        img, srcRect, dstRect, Paint()..filterQuality = FilterQuality.medium);

    // 邊框
    canvas.drawRect(
      dstRect,
      Paint()
        ..color = Colors.grey.shade600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawDistanceLines(Canvas canvas, Size size) {
    for (final pair in distancePairs) {
      if (pair.anchorA >= anchors.length || pair.anchorB >= anchors.length) {
        continue;
      }

      final a = anchors[pair.anchorA];
      final b = anchors[pair.anchorB];
      final start = Offset(a.pixelX, a.pixelY);
      final end = Offset(b.pixelX, b.pixelY);

      // 虛線
      final paint = Paint()
        ..color = Colors.blue.shade400
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(start, end, paint);

      // 距離標籤
      if (pair.distance > 0) {
        final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
        final labelBg = Paint()..color = Colors.white;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: mid, width: 60, height: 20),
            const Radius.circular(4),
          ),
          labelBg,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: mid, width: 60, height: 20),
            const Radius.circular(4),
          ),
          Paint()
            ..color = Colors.blue.shade400
            ..style = PaintingStyle.stroke,
        );

        final tp = TextPainter(
          text: TextSpan(
            text: '${pair.distance}m',
            style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
      }
    }
  }

  void _drawAnchor(Canvas canvas, _CalibrationAnchor anchor, int index) {
    final pos = Offset(anchor.pixelX, anchor.pixelY);
    final color = _anchorColors[index % _anchorColors.length];
    final isSelected = index == selectedIndex;
    final isSecond = index == secondIndex;

    // 選中光暈
    if (isSelected || isSecond) {
      canvas.drawCircle(
        pos,
        24,
        Paint()
          ..color =
              (isSelected ? Colors.blue : Colors.orange).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // 陰影
    canvas.drawCircle(
      pos + const Offset(2, 2),
      14,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // 基站圓圈
    canvas.drawCircle(pos, 14, Paint()..color = color);
    canvas.drawCircle(
      pos,
      14,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 序號
    final tp = TextPainter(
      text: TextSpan(
        text: '${index + 1}',
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));

    // 名稱標籤
    final nameTp = TextPainter(
      text: TextSpan(
        text: anchor.name,
        style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    nameTp.layout();

    // 標籤背景
    final labelRect = Rect.fromLTWH(
      pos.dx - nameTp.width / 2 - 4,
      pos.dy + 18,
      nameTp.width + 8,
      nameTp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    nameTp.paint(canvas, Offset(pos.dx - nameTp.width / 2, pos.dy + 20));

    // 座標標籤
    if (anchor.realX != null && anchor.realY != null) {
      final coordTp = TextPainter(
        text: TextSpan(
          text:
              '(${anchor.realX!.toStringAsFixed(2)}, ${anchor.realY!.toStringAsFixed(2)})',
          style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 9,
              fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      );
      coordTp.layout();
      final coordRect = Rect.fromLTWH(
        pos.dx - coordTp.width / 2 - 3,
        pos.dy + 32,
        coordTp.width + 6,
        coordTp.height + 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(coordRect, const Radius.circular(3)),
        Paint()..color = Colors.green.shade50,
      );
      coordTp.paint(canvas, Offset(pos.dx - coordTp.width / 2, pos.dy + 33));
    }
  }

  @override
  bool shouldRepaint(covariant _CalibrationPainter oldDelegate) => true;
}
