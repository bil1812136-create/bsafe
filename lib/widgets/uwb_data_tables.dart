import 'package:flutter/material.dart';
import 'package:bsafe_app/models/uwb_model.dart';
import 'package:bsafe_app/services/uwb_service.dart';
import 'package:bsafe_app/theme/app_theme.dart';

/// 基站列表组件 - 复制安信可应用的基站表格
class AnchorListTable extends StatefulWidget {
  final List<UwbAnchor> anchors;
  final Function(int, UwbAnchor)? onAnchorChanged;
  final VoidCallback? onAddAnchor;
  final Function(int)? onDeleteAnchor;
  final Function(int, String)? onRenameAnchor;

  const AnchorListTable({
    super.key,
    required this.anchors,
    this.onAnchorChanged,
    this.onAddAnchor,
    this.onDeleteAnchor,
    this.onRenameAnchor,
  });

  @override
  State<AnchorListTable> createState() => _AnchorListTableState();
}

class _AnchorListTableState extends State<AnchorListTable> {
  // Track which row is being edited
  int? _editingIndex;

  // Controllers for editing
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();
  final TextEditingController _zController = TextEditingController();

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _zController.dispose();
    super.dispose();
  }

  void _startEditing(int index, UwbAnchor anchor) {
    setState(() {
      _editingIndex = index;
      _xController.text = anchor.x.toStringAsFixed(2);
      _yController.text = anchor.y.toStringAsFixed(2);
      _zController.text = anchor.z.toStringAsFixed(2);
    });
  }

  void _saveEditing(int index, UwbAnchor anchor) {
    final newX = double.tryParse(_xController.text) ?? anchor.x;
    final newY = double.tryParse(_yController.text) ?? anchor.y;
    final newZ = double.tryParse(_zController.text) ?? anchor.z;

    if (widget.onAnchorChanged != null) {
      widget.onAnchorChanged!(
          index,
          UwbAnchor(
            id: anchor.id,
            x: newX,
            y: newY,
            z: newZ,
            isActive: anchor.isActive,
          ));
    }

    setState(() {
      _editingIndex = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                _buildHeaderCell('基站ID', flex: 2),
                _buildHeaderCell('X軸\n(m)', flex: 2),
                _buildHeaderCell('Y軸\n(m)', flex: 2),
                _buildHeaderCell('Z軸\n(m)', flex: 2),
                const SizedBox(width: 50), // Space for action buttons
              ],
            ),
          ),
          const Divider(height: 1),
          // 数据行
          ...widget.anchors.asMap().entries.map((entry) {
            final index = entry.key;
            final anchor = entry.value;
            return _buildAnchorRow(context, index, anchor);
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAnchorRow(BuildContext context, int index, UwbAnchor anchor) {
    final isEditing = _editingIndex == index;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEditing
            ? Colors.blue.shade50
            : (index.isEven ? Colors.white : Colors.grey.shade50),
      ),
      child: Row(
        children: [
          // 复选框 + ID
          Expanded(
            flex: 2,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: anchor.isActive,
                    onChanged: (v) {
                      if (widget.onAnchorChanged != null) {
                        widget.onAnchorChanged!(
                            index,
                            UwbAnchor(
                              id: anchor.id,
                              x: anchor.x,
                              y: anchor.y,
                              z: anchor.z,
                              isActive: v ?? true,
                            ));
                      }
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showRenameDialog(context, index, anchor),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            anchor.id,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.edit, size: 12, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // X
          Expanded(
            flex: 2,
            child: isEditing
                ? _buildEditableCell(_xController)
                : GestureDetector(
                    onTap: () => _startEditing(index, anchor),
                    child: Text(
                      anchor.x.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.primaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          // Y
          Expanded(
            flex: 2,
            child: isEditing
                ? _buildEditableCell(_yController)
                : GestureDetector(
                    onTap: () => _startEditing(index, anchor),
                    child: Text(
                      anchor.y.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.primaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          // Z
          Expanded(
            flex: 2,
            child: isEditing
                ? _buildEditableCell(_zController)
                : GestureDetector(
                    onTap: () => _startEditing(index, anchor),
                    child: Text(
                      anchor.z.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.primaryColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          // Action buttons
          SizedBox(
            width: 50,
            child: isEditing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Save button
                      SizedBox(
                        width: 24,
                        child: IconButton(
                          onPressed: () => _saveEditing(index, anchor),
                          icon: Icon(Icons.check,
                              size: 16, color: Colors.green.shade600),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '保存',
                        ),
                      ),
                      // Cancel button
                      SizedBox(
                        width: 24,
                        child: IconButton(
                          onPressed: _cancelEditing,
                          icon: Icon(Icons.close,
                              size: 16, color: Colors.red.shade400),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '取消',
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button
                      SizedBox(
                        width: 24,
                        child: IconButton(
                          onPressed: () => _startEditing(index, anchor),
                          icon: const Icon(Icons.edit_outlined,
                              size: 16, color: AppTheme.primaryColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '編輯座標',
                        ),
                      ),
                      // Delete button
                      SizedBox(
                        width: 24,
                        child: IconButton(
                          onPressed: widget.onDeleteAnchor != null
                              ? () => widget.onDeleteAnchor!(index)
                              : null,
                          icon: Icon(Icons.delete_outline,
                              size: 16, color: Colors.red.shade400),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '刪除基站',
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableCell(TextEditingController controller) {
    return Container(
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: TextField(
        controller: controller,
        enabled: true,
        autofocus: true,
        style: const TextStyle(fontSize: 12),
        textAlign: TextAlign.center,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppTheme.primaryColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide:
                const BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  // 显示重命名对话框
  void _showRenameDialog(BuildContext context, int index, UwbAnchor anchor) {
    final controller = TextEditingController(text: anchor.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名基站'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '基站名稱',
            hintText: '輸入新名稱',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && widget.onRenameAnchor != null) {
                widget.onRenameAnchor!(index, newName);
              }
              Navigator.pop(context);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}

/// 标签列表组件 - 复制安信可应用的标签表格
class TagListTable extends StatelessWidget {
  final UwbTag? currentTag;
  final List<UwbAnchor> anchors;

  const TagListTable({
    super.key,
    this.currentTag,
    required this.anchors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基站辨識提示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      '基站辨識方法',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '將標籤放在某個基站旁邊，觀察哪個距離接近 0。\n'
                  '例：標籤放在左下角 → D0 最小 → 該基站是基站0',
                  style: TextStyle(fontSize: 10, color: Colors.blue.shade600),
                ),
              ],
            ),
          ),
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildHeaderCell('標籤ID', width: 60),
                  _buildHeaderCell('X軸\n(m)', width: 50),
                  _buildHeaderCell('Y軸\n(m)', width: 50),
                  _buildHeaderCell('Z軸\n(m)', width: 50),
                  _buildHeaderCell('R95\n(m)', width: 50),
                  // 基站距离列 - 顯示 D0, D1, D2, D3
                  for (int i = 0; i < anchors.length && i < 8; i++)
                    _buildHeaderCell('D$i\n距離(m)', width: 60),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // 数据行
          if (currentTag != null) _buildTagRow(currentTag!),
          if (currentTag == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '等待標籤數據...',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {double width = 50}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTagRow(UwbTag tag) {
    // 找出最小距離的基站索引
    int? minDistanceIndex;
    double minDistance = double.infinity;
    for (int i = 0; i < anchors.length && i < 8; i++) {
      final dist = tag.anchorDistances[anchors[i].id];
      if (dist != null && dist > 0 && dist < minDistance) {
        minDistance = dist;
        minDistanceIndex = i;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 复选框 + ID
            SizedBox(
              width: 60,
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: true,
                      onChanged: (v) {},
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tag.id,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // X
            SizedBox(
              width: 50,
              child: Text(
                tag.x.toStringAsFixed(3),
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            // Y
            SizedBox(
              width: 50,
              child: Text(
                tag.y.toStringAsFixed(3),
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            // Z
            SizedBox(
              width: 50,
              child: Text(
                tag.z.toStringAsFixed(3),
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            // R95
            SizedBox(
              width: 50,
              child: Text(
                tag.r95.toStringAsFixed(3),
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            // 基站距离 - 高亮顯示最小距離
            for (int i = 0; i < anchors.length && i < 8; i++)
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: minDistanceIndex == i ? Colors.green.shade100 : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag.anchorDistances[anchors[i].id]?.toStringAsFixed(3) ?? '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: minDistanceIndex == i
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: minDistanceIndex == i
                        ? Colors.green.shade700
                        : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 完整的数据面板 - 包含基站和标签表格
class UwbDataPanel extends StatefulWidget {
  final UwbService uwbService;

  const UwbDataPanel({
    super.key,
    required this.uwbService,
  });

  @override
  State<UwbDataPanel> createState() => _UwbDataPanelState();
}

class _UwbDataPanelState extends State<UwbDataPanel> {
  UwbService get uwbService => widget.uwbService;

  // 显示新增基站对话框
  void _showAddAnchorDialog(BuildContext context) {
    final idController =
        TextEditingController(text: '基站${uwbService.anchors.length}');
    final xController = TextEditingController(text: '0.00');
    final yController = TextEditingController(text: '0.00');
    final zController = TextEditingController(text: '3.00');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cell_tower, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('新增基站'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: '基站 ID',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: xController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'X (m)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: yController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Y (m)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: zController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Z (m)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final x = double.tryParse(xController.text) ?? 0.0;
              final y = double.tryParse(yController.text) ?? 0.0;
              final z = double.tryParse(zController.text) ?? 3.0;

              uwbService.addAnchor(UwbAnchor(
                id: idController.text,
                x: x,
                y: y,
                z: z,
              ));

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已新增基站: ${idController.text}')),
              );
            },
            child: const Text('新增'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 基站表格
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基站列表
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Text(
                          '基站列表',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // 新增基站按钮
                        SizedBox(
                          height: 28,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddAnchorDialog(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('新增',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnchorListTable(
                    anchors: uwbService.anchors,
                    onAnchorChanged: (index, anchor) {
                      uwbService.updateAnchor(index, anchor);
                    },
                    onAddAnchor: () => _showAddAnchorDialog(context),
                    onDeleteAnchor: (index) {
                      uwbService.removeAnchor(index);
                    },
                    onRenameAnchor: (index, newName) {
                      uwbService.renameAnchor(index, newName);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // 标签列表和原始数据
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '標籤列表',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TagListTable(
                    currentTag: uwbService.currentTag,
                    anchors: uwbService.anchors,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
