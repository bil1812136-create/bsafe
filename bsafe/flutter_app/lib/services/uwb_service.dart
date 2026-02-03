import 'dart:async';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:bsafe_app/models/uwb_model.dart';
import 'package:bsafe_app/services/desktop_serial_service.dart';

/// UWB定位服务
/// 提供与安信可UWB TWR系统的通信和数据处理
class UwbService extends ChangeNotifier {
  // 连接状态
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 连接模式
  bool _isRealDevice = false;
  bool get isRealDevice => _isRealDevice;

  // 基站列表
  List<UwbAnchor> _anchors = [];
  List<UwbAnchor> get anchors => _anchors;

  // 当前标签
  UwbTag? _currentTag;
  UwbTag? get currentTag => _currentTag;

  // 轨迹历史
  final List<TrajectoryPoint> _trajectory = [];
  List<TrajectoryPoint> get trajectory => _trajectory;

  // 配置
  UwbConfig _config = UwbConfig();
  UwbConfig get config => _config;

  // 串口服务（桌面平台）
  DesktopSerialService? _desktopSerial;

  // 串口设置
  String _portName = 'COM3';
  int _baudRate = 115200;

  // 串口数据订阅
  StreamSubscription<String>? _serialSubscription;

  // 模拟数据定时器
  Timer? _simulationTimer;

  // UI 刷新定時器 (確保每秒更新)
  Timer? _uiRefreshTimer;

  // 错误信息
  String? _lastError;
  String? get lastError => _lastError;

  // 數據接收統計 (調試用)
  DateTime? _lastDataTime;
  int _dataReceiveCount = 0;
  DateTime? get lastDataTime => _lastDataTime;
  int get dataReceiveCount => _dataReceiveCount;

  // ===== 位置濾波器 (減少抖動) =====
  final List<double> _xHistory = [];
  final List<double> _yHistory = [];
  static const int _filterWindowSize = 2; // 滑動平均窗口大小 (減小以加快響應)

  // 距離歷史 (用於中值濾波)
  final Map<int, List<double>> _distanceHistory = {};
  static const int _distanceFilterSize = 2; // 減小以加快響應

  // 原始数据缓存 (用于调试)
  final List<String> _rawDataLog = [];
  List<String> get rawDataLog => _rawDataLog;

  // 清除原始数据日志
  void clearRawDataLog() {
    _rawDataLog.clear();
    notifyListeners();
  }

  // 清除错误
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // 初始化默认基站配置 (基于安信可 TWR App 截图)
  void initializeDefaultAnchors() {
    _anchors = [
      UwbAnchor(id: '基站0', x: 0.00, y: 0.00, z: 3.00),
      UwbAnchor(id: '基站1', x: -6.84, y: 0.00, z: 3.00),
      UwbAnchor(id: '基站2', x: 0.00, y: -5.51, z: 3.00),
      UwbAnchor(id: '基站3', x: -5.34, y: -5.51, z: 3.00),
    ];
    notifyListeners();
  }

  // 更新基站配置
  void updateAnchor(int index, UwbAnchor anchor) {
    if (index >= 0 && index < _anchors.length) {
      _anchors[index] = anchor;
      notifyListeners();
    }
  }

  // 重命名基站
  void renameAnchor(int index, String newName) {
    if (index >= 0 && index < _anchors.length) {
      final old = _anchors[index];
      _anchors[index] = UwbAnchor(
        id: newName,
        x: old.x,
        y: old.y,
        z: old.z,
        isActive: old.isActive,
      );
      notifyListeners();
    }
  }

  // 添加基站
  void addAnchor(UwbAnchor anchor) {
    _anchors.add(anchor);
    notifyListeners();
  }

  // 移除基站
  void removeAnchor(int index) {
    if (index >= 0 && index < _anchors.length) {
      _anchors.removeAt(index);
      notifyListeners();
    }
  }

  // 更新配置
  void updateConfig(UwbConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  // 连接真实UWB设备 (跨平台支持)
  Future<bool> connectRealDevice() async {
    try {
      _lastError = null;

      // 桌面平台 (Windows/Linux/macOS)
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        _desktopSerial = DesktopSerialService();

        // 获取可用串口
        final ports = _desktopSerial!.getAvailablePorts();
        debugPrint('可用串口: $ports');

        if (ports.isEmpty) {
          _lastError = '未找到可用串口設備，請確保 BU04 已連接';
          notifyListeners();
          return false;
        }

        // 尝试自动连接
        final connected =
            await _desktopSerial!.autoConnect(baudRate: _baudRate);

        if (connected) {
          // 订阅串口数据
          _serialSubscription = _desktopSerial!.dataStream.listen(
            (data) {
              processSerialData(data);
            },
            onError: (error) {
              _lastError = '串口錯誤: $error';
              notifyListeners();
            },
          );

          _isConnected = true;
          _isRealDevice = true;
          notifyListeners();
          return true;
        } else {
          _lastError = '無法連接串口，請檢查設備';
          notifyListeners();
          return false;
        }
      }

      // Web 平台
      if (kIsWeb) {
        _lastError = '真實設備連接僅支持 Web 平台';
        notifyListeners();
        return false;
      }

      // 其他平台
      _lastError = '當前平台不支持串口連接';
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = '連接錯誤: $e';
      debugPrint('连接真实设备失败: $e');
      notifyListeners();
      return false;
    }
  }

  // 连接到指定串口（用于选择特定设备）
  Future<bool> connectToPort(String portName, {int? baudRate}) async {
    try {
      _lastError = null;
      _portName = portName;
      _baudRate = baudRate ?? _baudRate;

      // 桌面平台 (Windows/Linux/macOS)
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        _desktopSerial = DesktopSerialService();

        debugPrint('嘗試連接串口: $portName');

        // 连接指定串口
        final connected =
            await _desktopSerial!.connect(portName, baudRate: _baudRate);

        if (connected) {
          // 订阅串口数据
          _serialSubscription = _desktopSerial!.dataStream.listen(
            (data) {
              processSerialData(data);
            },
            onError: (error) {
              _lastError = '串口錯誤: $error';
              notifyListeners();
            },
          );

          _isConnected = true;
          _isRealDevice = true;

          // 啟動 UI 刷新定時器 (每秒刷新一次)
          _startUiRefreshTimer();

          notifyListeners();
          debugPrint('成功連接到 $portName');
          return true;
        } else {
          _lastError = '無法連接到 $portName';
          notifyListeners();
          return false;
        }
      }

      _lastError = '當前平台不支持串口連接';
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = '連接錯誤: $e';
      debugPrint('连接串口失败: $e');
      notifyListeners();
      return false;
    }
  }

  // 连接模拟设备
  Future<bool> connect(
      {String? port, int? baudRate, bool simulate = true}) async {
    _portName = port ?? _portName;
    _baudRate = baudRate ?? _baudRate;
    _lastError = null;

    if (!simulate) {
      return connectRealDevice();
    }

    // 模拟连接延迟
    await Future.delayed(const Duration(milliseconds: 500));

    _isConnected = true;
    _isRealDevice = false;
    notifyListeners();

    // 开始模拟数据
    startSimulation();

    return true;
  }

  // 断开连接
  void disconnect() {
    _isConnected = false;
    _isRealDevice = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = null;
    _serialSubscription?.cancel();
    _serialSubscription = null;

    // 断开桌面串口
    _desktopSerial?.disconnect();
    _desktopSerial = null;

    notifyListeners();
  }

  // 啟動 UI 刷新定時器 - 實時刷新 (每50毫秒，約20fps)
  void _startUiRefreshTimer() {
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isConnected) {
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  // 处理从串口接收到的数据 - 即時更新
  void processSerialData(String data) {
    // 記錄原始數據（減少日誌以提高性能）
    if (_rawDataLog.length < 50) {
      final hexData = data.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      _rawDataLog
          .add('[${DateTime.now().toString().substring(11, 19)}] HEX: $hexData');
    }
    if (_rawDataLog.length > 50) {
      _rawDataLog.removeAt(0);
    }

    // 調試：記錄收到數據
    _lastDataTime = DateTime.now();
    _dataReceiveCount++;

    final tag = parseUwbData(data);
    if (tag != null) {
      _currentTag = tag;

      // 添加轨迹点 - 只有位置有效時才添加
      if (_config.showTrajectory && (tag.x != 0 || tag.y != 0)) {
        _trajectory.add(TrajectoryPoint(x: tag.x, y: tag.y));
        if (_trajectory.length > 500) {
          _trajectory.removeAt(0);
        }
      }

      // 立即通知UI更新 - 實時顯示
      notifyListeners();
    } else {
      // 即使解析失敗也更新UI（顯示原始數據）
      notifyListeners();
    }
  }

  // 开始模拟数据 (用于演示)
  void startSimulation() {
    if (_simulationTimer != null) return;

    final random = Random();
    final double baseX = 4.5;
    final double baseY = 1.8;
    double angle = 0;

    _simulationTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }

      // 模拟标签移动 (圆形轨迹)
      angle += 0.05;
      final double radius = 0.5 + random.nextDouble() * 0.3;
      double newX =
          baseX + cos(angle) * radius + (random.nextDouble() - 0.5) * 0.1;
      double newY =
          baseY + sin(angle) * radius + (random.nextDouble() - 0.5) * 0.1;

      // 限制在区域内
      newX = newX.clamp(-8.0, 2.0);
      newY = newY.clamp(-7.0, 2.0);

      // 计算到各基站的距离
      final Map<String, double> distances = {};
      for (var anchor in _anchors) {
        final double dx = newX - anchor.x;
        final double dy = newY - anchor.y;
        final double dz = 0 - anchor.z; // 假设标签在地面
        double distance = sqrt(dx * dx + dy * dy + dz * dz);
        // 应用距离校正
        distance = distance * _config.correctionA + _config.correctionB;
        distances[anchor.id] = double.parse(distance.toStringAsFixed(3));
      }

      // 更新标签数据
      _currentTag = UwbTag(
        id: '标签0',
        x: double.parse(newX.toStringAsFixed(3)),
        y: double.parse(newY.toStringAsFixed(3)),
        z: 0.0,
        r95: double.parse((random.nextDouble() * 0.1).toStringAsFixed(3)),
        anchorDistances: distances,
      );

      // 添加轨迹点
      if (_config.showTrajectory) {
        _trajectory.add(TrajectoryPoint(x: newX, y: newY));
        // 限制轨迹长度
        if (_trajectory.length > 500) {
          _trajectory.removeAt(0);
        }
      }

      notifyListeners();
    });
  }

  // 停止模拟
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  // 清除轨迹
  void clearTrajectory() {
    _trajectory.clear();
    notifyListeners();
  }

  // 解析安信可UWB数据格式
  // 支持多种格式:
  // 1. mc格式: "mc 00 00001234 00001234 00001234 00001234 0353 189a 0030 0001 c70f"
  // 2. 简化格式: "TAG:0 X:4.533 Y:1.868 Z:0.000 Q:95"
  // 3. JSON格式: {"tag":"0","x":4.533,"y":1.868,"z":0.0,"d0":5.07,"d1":3.104,"d2":4.118,"d3":2.964}
  // 4. 安信可TWR格式: "mr 00 00001234 00001234 00001234 00001234..."
  // 5. 距离格式: "dis:0,d0:5070,d1:3104,d2:4118,d3:2964"
  // 6. 位置格式: "pos:0,x:4533,y:1868,z:0"
  // 7. CmdM二进制格式: "CmdM:4[二进制数据]"
  // 8. RAWBIN格式: "RAWBIN:length:hex_bytes" (原始二进制)
  UwbTag? parseUwbData(String data) {
    try {
      data = data.trim();
      if (data.isEmpty) return null;

      // 优先解析 RAWBIN 原始二进制格式
      if (data.startsWith('RAWBIN:')) {
        return _parseCmdMFormat(data);
      }

      // 尝试解析 CmdM 二进制格式 (安信可原始二进制协议)
      if (data.startsWith('CmdM')) {
        return _parseCmdMFormat(data);
      }

      // 尝试解析 JSON 格式
      if (data.startsWith('{')) {
        return _parseJsonFormat(data);
      }

      // 尝试解析 TAG 格式
      if (data.toUpperCase().startsWith('TAG')) {
        return _parseTagFormat(data);
      }

      // 尝试解析 mc/mr 格式 (安信可原始格式)
      if (data.startsWith('mc') || data.startsWith('mr')) {
        return _parseMcFormat(data);
      }

      // 尝试解析 pos 格式 (位置数据)
      if (data.toLowerCase().startsWith('pos')) {
        return _parsePosFormat(data);
      }

      // 尝试解析 dis 格式 (距离数据)
      if (data.toLowerCase().startsWith('dis')) {
        return _parseDisFormat(data);
      }

      // 尝试解析带有 x: y: 的格式
      if (data.toLowerCase().contains('x:') &&
          data.toLowerCase().contains('y:')) {
        return _parseXYFormat(data);
      }

      // 尝试解析纯坐标格式 (x,y,z)
      if (data.contains(',') && !data.contains(':')) {
        return _parseSimpleFormat(data);
      }

      // 尝试解析空格分隔的数字格式
      if (RegExp(r'^[\d\s.,-]+$').hasMatch(data)) {
        return _parseSpaceSeparatedFormat(data);
      }

      return null;
    } catch (e) {
      debugPrint('解析UWB数据失败: $e');
      return null;
    }
  }

  // 解析 CmdM 二进制格式 (安信可 BU04 原始协议)
  // 现在接收 RAWBIN:length:hexdata 格式
  // BU04 TWR 数据格式:
  // CmdM:4[数据] 其中数据包含多个基站的距离信息
  UwbTag? _parseCmdMFormat(String data) {
    try {
      // 新格式: RAWBIN:length:hex_bytes
      if (data.startsWith('RAWBIN:')) {
        return _parseRawBinaryFormat(data);
      }

      // 旧格式兼容
      if (data.length < 10) return null;

      final bracketIndex = data.indexOf('[');
      if (bracketIndex < 0) return null;

      return null;
    } catch (e) {
      debugPrint('CmdM格式解析错误: $e');
      return null;
    }
  }

  // 解析原始二进制数据
  // 格式: RAWBIN:length:43 6d 64 4d 3a 34 5b ...
  // BU04 TWR 模式實際數據格式 (根據實際抓包分析):
  // "CmdM:4[" + 二進制數據 + "]"
  // 91 字節數據: [時間戳8B][D0 2B][D1 2B][00...][數據重複]
  UwbTag? _parseRawBinaryFormat(String data) {
    try {
      final parts = data.split(':');
      if (parts.length < 3) return null;

      final hexString = parts.sublist(2).join(':');
      final hexBytes = hexString.split(' ');

      // 转换为字节数组
      final bytes =
          hexBytes.map((h) => int.tryParse(h, radix: 16) ?? 0).toList();

      // 找到 '[' (0x5b) 和 ']' (0x5d) 來定位數據區域
      final bracketStart = bytes.indexOf(0x5b);
      final bracketEnd = bytes.lastIndexOf(0x5d);

      if (bracketStart < 0 || bracketEnd <= bracketStart) {
        return null;
      }

      // 提取 '[' 和 ']' 之間的數據
      final dataBytes = bytes.sublist(bracketStart + 1, bracketEnd);

      // 忽略太短的數據包
      if (dataBytes.length < 12) {
        return null;
      }

      // 調試輸出已關閉以提高性能
      // debugPrint('BU04 數據區 (${dataBytes.length} bytes): ${dataBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      // for (int pos = 0; pos < dataBytes.length - 1; pos += 2) { ... }

      // ===== 根據實際數據分析 BU04 TWR 協議 =====
      // 91字節數據格式 (基於實際抓包):
      // [0-7]: 時間戳/序號 (8 bytes)
      // [8-9]: D0 距離 (2 bytes, 小端序, 毫米)
      // [10-11]: D1 距離 (2 bytes)
      // [12-13]: 保留/填充 (通常為0)
      // [14-15]: D2 距離 (2 bytes) - 確認位置
      // [16-17]: 保留/填充 (通常為0)
      // [18-19]: D2 距離 (2 bytes) - 確認位置
      // [22-23]: D3 距離 (2 bytes)
      // ...數據可能在後面重複

      final List<double> distances = [-1.0, -1.0, -1.0, -1.0];

      // 讀取 D0 (位置 8-9) - 確定
      if (dataBytes.length > 9) {
        final int d0mm = dataBytes[8] | (dataBytes[9] << 8);
        if (d0mm > 50 && d0mm < 20000) {
          distances[0] = d0mm / 1000.0;
        }
      }

      // 讀取 D1 (位置 10-11) - 確定
      if (dataBytes.length > 11) {
        final int d1mm = dataBytes[10] | (dataBytes[11] << 8);
        if (d1mm > 50 && d1mm < 20000) {
          distances[1] = d1mm / 1000.0;
        }
      }

      // D2 在位置 18-19 (根據實際數據分析確認)
      if (dataBytes.length > 19) {
        final int d2mm = dataBytes[18] | (dataBytes[19] << 8);
        if (d2mm > 50 && d2mm < 20000) {
          distances[2] = d2mm / 1000.0;
        }
      }

      // D3 在位置 22-23
      if (dataBytes.length > 23) {
        final int d3mm = dataBytes[22] | (dataBytes[23] << 8);
        if (d3mm > 50 && d3mm < 20000) {
          distances[3] = d3mm / 1000.0;
        }
      }

      // 如果 D2/D3 還沒找到，搜索其他位置
      if (distances[2] < 0 || distances[3] < 0) {
        // 擴展搜索範圍
        final List<int> candidatePositions = [
          12,
          14,
          16,
          18,
          20,
          24,
          28,
          30,
          32,
          34
        ];
        final List<int> validDistanceValues = [];

        for (int pos in candidatePositions) {
          if (pos + 1 < dataBytes.length) {
            final int val = dataBytes[pos] | (dataBytes[pos + 1] << 8);
            // 有效距離範圍: 50mm - 20000mm
            if (val > 50 && val < 20000) {
              validDistanceValues.add(val);
            }
          }
        }

        // 找不同於 D0, D1 的值作為 D2, D3
        final d0Raw = distances[0] > 0 ? (distances[0] * 1000).round() : -1;
        final d1Raw = distances[1] > 0 ? (distances[1] * 1000).round() : -1;

        for (int val in validDistanceValues) {
          // 如果這個值與 D0 或 D1 差距大於 10%，則視為新的距離
          final bool notD0 = d0Raw < 0 || (val - d0Raw).abs() > d0Raw * 0.10;
          final bool notD1 = d1Raw < 0 || (val - d1Raw).abs() > d1Raw * 0.10;

          if (notD0 && notD1) {
            if (distances[2] < 0) {
              distances[2] = val / 1000.0;
            } else if (distances[3] < 0 &&
                (val - distances[2] * 1000).abs() > 100) {
              distances[3] = val / 1000.0;
              break;
            }
          }
        }
      }

      // ===== 應用安信可距離校正係數 =====
      final double corrA = _config.correctionA; // 0.78
      final double corrB = _config.correctionB; // 0.0

      for (int i = 0; i < distances.length; i++) {
        if (distances[i] > 0) {
          distances[i] = distances[i] * corrA + corrB;
        }
      }

      // 计算有效距离数量
      final validCount = distances.where((d) => d > 0).length;

      // debugPrint('BU04 (校正後): D0=${distances[0].toStringAsFixed(2)}m, D1=${distances[1].toStringAsFixed(2)}m, D2=${distances[2].toStringAsFixed(2)}m, D3=${distances[3].toStringAsFixed(2)}m');
      // debugPrint('有效距離數: $validCount, 基站數: ${_anchors.length}');

      if (validCount >= 2) {
        // 確保基站已初始化
        if (_anchors.isEmpty) {
          debugPrint('警告: 基站未初始化，正在初始化默認基站');
          initializeDefaultAnchors();
        }

        // 使用三边定位 (需要至少 3 個距離)
        if (validCount >= 3 && _anchors.length >= 3) {
          final pos = _trilaterationWithDistances(distances);
          if (pos != null) {
            return _createTagWithMeasuredDistances(
                pos.$1, pos.$2, 0.0, '0', distances);
          }
        }

        // 如果只有 2 個距離，使用雙圓交點估算
        // debugPrint('嘗試雙圓交點定位...');
        final pos = _twoCircleIntersection(distances);
        if (pos != null) {
          // debugPrint('雙圓交點計算成功: x=${pos.$1.toStringAsFixed(2)}, y=${pos.$2.toStringAsFixed(2)}');
          return _createTagWithMeasuredDistances(
              pos.$1, pos.$2, 0.0, '0', distances);
        } else {
          // debugPrint('雙圓交點計算失敗');
        }

        // 至少返回距離數據
        return _createTagWithMeasuredDistances(0, 0, 0, '0', distances);
      }

      return null;
    } catch (e) {
      debugPrint('解析错误: $e');
      return null;
    }
  }

  // 使用兩個距離進行雙圓交點定位 (精度較低)
  (double, double)? _twoCircleIntersection(List<double> distances) {
    // 找到有效的兩個基站
    final List<int> validIndices = [];
    for (int i = 0; i < min(distances.length, _anchors.length); i++) {
      if (distances[i] > 0 && _anchors[i].isActive) {
        validIndices.add(i);
      }
    }

    // debugPrint('雙圓交點: 有效基站索引=$validIndices, 基站總數=${_anchors.length}');

    if (validIndices.length < 2) {
      // debugPrint('雙圓交點: 有效基站不足2個');
      return null;
    }

    final a1 = _anchors[validIndices[0]];
    final a2 = _anchors[validIndices[1]];
    final r1 = distances[validIndices[0]];
    final r2 = distances[validIndices[1]];

    // debugPrint('雙圓交點: A1=(${a1.x}, ${a1.y}), A2=(${a2.x}, ${a2.y}), R1=$r1, R2=$r2');

    // 考慮高度校正 (基站高度 - 標籤高度)
    final double tagHeight = 1.0; // 假設標籤高度
    final dz1 = (a1.z - tagHeight).abs();
    final dz2 = (a2.z - tagHeight).abs();

    // 3D 距離轉換為 2D 水平距離
    final d1 = r1 > dz1 ? sqrt(r1 * r1 - dz1 * dz1) : r1 * 0.8;
    final d2 = r2 > dz2 ? sqrt(r2 * r2 - dz2 * dz2) : r2 * 0.8;

    // debugPrint('雙圓交點: 高度校正後 d1=$d1, d2=$d2');

    // 計算兩圓交點
    final dx = a2.x - a1.x;
    final dy = a2.y - a1.y;
    final d = sqrt(dx * dx + dy * dy);

    // debugPrint('雙圓交點: 基站間距 d=$d');

    if (d < 0.01 || d > d1 + d2 + 1.0) {
      // 兩圓不相交或重合，返回連線上的估計位置
      final ratio = d1 / (d1 + d2 + 0.001);
      return _smoothPosition(
        a1.x + dx * ratio,
        a1.y + dy * ratio,
      );
    }

    // 計算交點
    final a = (d1 * d1 - d2 * d2 + d * d) / (2 * d);
    final hSq = d1 * d1 - a * a;

    if (hSq < 0) {
      // 無交點，返回估計位置
      final ratio = d1 / (d1 + d2 + 0.001);
      return _smoothPosition(
        a1.x + dx * ratio,
        a1.y + dy * ratio,
      );
    }

    final hVal = sqrt(hSq);

    // 中點
    final px = a1.x + a * dx / d;
    final py = a1.y + a * dy / d;

    // 兩個交點
    final x1 = px + hVal * dy / d;
    final y1 = py - hVal * dx / d;
    final x2 = px - hVal * dy / d;
    final y2 = py + hVal * dx / d;

    // debugPrint('雙圓交點候選: (${x1.toStringAsFixed(2)}, ${y1.toStringAsFixed(2)}), (${x2.toStringAsFixed(2)}, ${y2.toStringAsFixed(2)})');

    // 選擇在合理範圍內的點
    // 根據基站配置 x: [-6.84, 0], y: [-5.51, 0]，標籤應該在這個範圍附近
    final bool valid1 = y1 >= -8.0 && y1 <= 2.0 && x1 >= -10.0 && x1 <= 2.0;
    final bool valid2 = y2 >= -8.0 && y2 <= 2.0 && x2 >= -10.0 && x2 <= 2.0;

    if (valid1 && valid2) {
      // 兩個都有效，選擇更接近區域中心的
      final centerX = -3.0; // 區域 x 中心
      final centerY = -2.75; // 區域 y 中心
      final dist1 =
          (x1 - centerX) * (x1 - centerX) + (y1 - centerY) * (y1 - centerY);
      final dist2 =
          (x2 - centerX) * (x2 - centerX) + (y2 - centerY) * (y2 - centerY);
      return dist1 < dist2 ? _smoothPosition(x1, y1) : _smoothPosition(x2, y2);
    } else if (valid1) {
      return _smoothPosition(x1, y1);
    } else if (valid2) {
      return _smoothPosition(x2, y2);
    } else {
      // 都不太合理，選擇更接近區域的
      return _smoothPosition(
        (x1 + x2) / 2,
        (y1 + y2) / 2,
      );
    }
  }

  // 中值濾波 - 減少距離測量噪聲
  double _medianFilter(int anchorIndex, double newDistance) {
    _distanceHistory.putIfAbsent(anchorIndex, () => []);
    final history = _distanceHistory[anchorIndex]!;

    history.add(newDistance);
    if (history.length > _distanceFilterSize) {
      history.removeAt(0);
    }

    if (history.length < 2) return newDistance;

    // 排序取中值
    final sorted = List<double>.from(history)..sort();
    return sorted[sorted.length ~/ 2];
  }

  // 滑動平均濾波 - 平滑位置輸出
  (double, double) _smoothPosition(double x, double y) {
    _xHistory.add(x);
    _yHistory.add(y);

    if (_xHistory.length > _filterWindowSize) {
      _xHistory.removeAt(0);
      _yHistory.removeAt(0);
    }

    // 計算加權平均 (最新的權重更高)
    double sumX = 0, sumY = 0, sumWeight = 0;
    for (int i = 0; i < _xHistory.length; i++) {
      final weight = i + 1.0; // 遞增權重
      sumX += _xHistory[i] * weight;
      sumY += _yHistory[i] * weight;
      sumWeight += weight;
    }

    return (sumX / sumWeight, sumY / sumWeight);
  }

  // 三边定位算法 - 改進版 (參考安信可實現)
  (double, double)? _trilaterationWithDistances(List<double> distances) {
    if (_anchors.length < 3 || distances.length < 3) return null;

    // 对距离进行中值滤波
    final filteredDistances = <double>[];
    for (int i = 0; i < distances.length; i++) {
      if (distances[i] > 0) {
        filteredDistances.add(_medianFilter(i, distances[i]));
      } else {
        filteredDistances.add(distances[i]);
      }
    }

    // 获取有效的基站和距离
    final List<UwbAnchor> validAnchors = [];
    final List<double> validDistances = [];

    // 估計標籤高度 (假設標籤在地面或桌面，約 0-1.5m)
    final double tagHeight = 1.0; // 假設標籤高度為 1m

    for (int i = 0; i < min(_anchors.length, filteredDistances.length); i++) {
      if (filteredDistances[i] > 0 && _anchors[i].isActive) {
        validAnchors.add(_anchors[i]);
        // 3D 距離轉換為 2D 水平距離
        final d3d = filteredDistances[i];
        final dz = (_anchors[i].z - tagHeight).abs(); // 垂直高度差
        // 如果 3D 距離大於垂直高度差，計算水平距離
        double d2d;
        if (d3d > dz) {
          d2d = sqrt(d3d * d3d - dz * dz);
        } else {
          // 距離太短，可能是測量誤差，使用較小的值
          d2d = d3d * 0.5;
        }
        validDistances.add(d2d);
      }
    }

    if (validAnchors.length < 3) return null;

    // ===== 使用加權最小二乘法 (WLS) =====
    // 以第一個基站為原點建立局部坐標系
    final double x1 = validAnchors[0].x;
    final double y1 = validAnchors[0].y;
    final double r1 = validDistances[0];

    // 構建超定方程組 Ax = b
    // 對於每對基站 (i, 1)，有方程:
    // 2(xi - x1)x + 2(yi - y1)y = ri² - r1² - xi² + x1² - yi² + y1²

    double sumAA = 0, sumAB = 0, sumBB = 0;
    double sumAC = 0, sumBC = 0;
    double sumWeight = 0;

    for (int i = 1; i < validAnchors.length; i++) {
      final double xi = validAnchors[i].x;
      final double yi = validAnchors[i].y;
      final double ri = validDistances[i];

      final double A = 2 * (xi - x1);
      final double B = 2 * (yi - y1);
      final double C =
          r1 * r1 - ri * ri - x1 * x1 + xi * xi - y1 * y1 + yi * yi;

      // 權重：距離越近的基站權重越高
      final double w = 1.0 / (ri + 0.1);

      sumAA += w * A * A;
      sumAB += w * A * B;
      sumBB += w * B * B;
      sumAC += w * A * C;
      sumBC += w * B * C;
      sumWeight += w;
    }

    // 解 2x2 線性方程組
    final double det = sumAA * sumBB - sumAB * sumAB;
    if (det.abs() < 1e-10) {
      return _fallbackTrilateration(validAnchors, validDistances);
    }

    double x = (sumBB * sumAC - sumAB * sumBC) / det;
    double y = (sumAA * sumBC - sumAB * sumAC) / det;

    // 迭代優化 (Gauss-Newton 優化殘差)
    for (int iter = 0; iter < 5; iter++) {
      double sumDx = 0, sumDy = 0;
      double totalW = 0;

      for (int i = 0; i < validAnchors.length; i++) {
        final ax = validAnchors[i].x;
        final ay = validAnchors[i].y;
        final r = validDistances[i];

        final dx = x - ax;
        final dy = y - ay;
        final currentDist = sqrt(dx * dx + dy * dy);

        if (currentDist < 0.001) continue;

        final residual = r - currentDist;
        final w = 1.0 / (r + 0.1);

        sumDx += residual * (dx / currentDist) * w;
        sumDy += residual * (dy / currentDist) * w;
        totalW += w;
      }

      if (totalW > 0) {
        x += (sumDx / totalW) * 0.3; // 小步長
        y += (sumDy / totalW) * 0.3;
      }
    }

    // 限制在合理範圍內
    x = x.clamp(-10.0, 2.0);
    y = y.clamp(-8.0, 2.0);

    // 驗證結果：檢查是否在基站構成的區域附近
    final minX = validAnchors.map((a) => a.x).reduce(min) - 1;
    final maxX = validAnchors.map((a) => a.x).reduce(max) + 1;
    final minY = validAnchors.map((a) => a.y).reduce(min) - 1;
    final maxY = validAnchors.map((a) => a.y).reduce(max) + 1;

    if (x < minX || x > maxX || y < minY || y > maxY) {
      // 結果超出合理範圍，使用備用算法
      return _fallbackTrilateration(validAnchors, validDistances);
    }

    // 應用位置平滑濾波
    return _smoothPosition(x, y);
  }

  // 備用三邊定位算法 (傳統線性化方法)
  (double, double)? _fallbackTrilateration(
      List<UwbAnchor> anchors, List<double> distances) {
    if (anchors.length < 3) return null;

    double x1 = anchors[0].x, y1 = anchors[0].y;
    final double r1 = distances[0];

    double sumX = 0, sumY = 0;
    double totalWeight = 0;

    for (int i = 1; i < anchors.length; i++) {
      for (int j = i + 1; j < anchors.length; j++) {
        double x2 = anchors[i].x, y2 = anchors[i].y;
        double x3 = anchors[j].x, y3 = anchors[j].y;
        final double r2 = distances[i];
        final double r3 = distances[j];

        final double A = 2 * (x2 - x1);
        final double B = 2 * (y2 - y1);
        final double C =
            r1 * r1 - r2 * r2 - x1 * x1 + x2 * x2 - y1 * y1 + y2 * y2;
        final double D = 2 * (x3 - x1);
        final double E = 2 * (y3 - y1);
        final double F =
            r1 * r1 - r3 * r3 - x1 * x1 + x3 * x3 - y1 * y1 + y3 * y3;

        final double det = A * E - B * D;
        if (det.abs() > 0.001) {
          final double x = (C * E - B * F) / det;
          final double y = (A * F - C * D) / det;

          if (x.isFinite &&
              y.isFinite &&
              x >= -5 &&
              x <= 20 &&
              y >= -5 &&
              y <= 20) {
            final weight = 1.0 / (r1 + r2 + r3);
            sumX += x * weight;
            sumY += y * weight;
            totalWeight += weight;
          }
        }
      }
    }

    if (totalWeight > 0) {
      return _smoothPosition(sumX / totalWeight, sumY / totalWeight);
    }
    return null;
  }

  // 创建带有测量距离的标签
  UwbTag _createTagWithMeasuredDistances(
      double x, double y, double z, String tagId, List<double> distances) {
    final Map<String, double> anchorDistances = {};
    for (int i = 0; i < min(_anchors.length, distances.length); i++) {
      if (distances[i] > 0) {
        anchorDistances[_anchors[i].id] = distances[i];
      }
    }

    return UwbTag(
      id: '标签$tagId',
      x: double.parse(x.toStringAsFixed(3)),
      y: double.parse(y.toStringAsFixed(3)),
      z: double.parse(z.toStringAsFixed(3)),
      r95: 0.1,
      anchorDistances: anchorDistances,
    );
  }

  // 解析 pos 格式: "pos:0,x:4533,y:1868,z:0" 或 "POS,0,4.533,1.868,0.000"
  UwbTag? _parsePosFormat(String data) {
    try {
      // 格式1: pos:0,x:4533,y:1868,z:0
      if (data.contains('x:')) {
        final xMatch = RegExp(r'x:(\d+)').firstMatch(data.toLowerCase());
        final yMatch = RegExp(r'y:(\d+)').firstMatch(data.toLowerCase());
        final zMatch = RegExp(r'z:(\d+)').firstMatch(data.toLowerCase());

        if (xMatch != null && yMatch != null) {
          // 值是毫米，需要转换为米
          final x = double.parse(xMatch.group(1)!) / 1000.0;
          final y = double.parse(yMatch.group(1)!) / 1000.0;
          final z =
              zMatch != null ? double.parse(zMatch.group(1)!) / 1000.0 : 0.0;

          return _createTagWithDistances(x, y, z);
        }
      }

      // 格式2: POS,0,4.533,1.868,0.000
      final parts = data.split(',');
      if (parts.length >= 4) {
        final x = double.tryParse(parts[2]);
        final y = double.tryParse(parts[3]);
        final z = parts.length > 4 ? double.tryParse(parts[4]) : 0.0;

        if (x != null && y != null) {
          return _createTagWithDistances(x, y, z ?? 0.0);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 解析 dis 格式: "dis:0,d0:5070,d1:3104,d2:4118,d3:2964"
  UwbTag? _parseDisFormat(String data) {
    try {
      final Map<String, double> distances = {};

      for (int i = 0; i < 8; i++) {
        final match = RegExp('d$i:(\\d+)').firstMatch(data.toLowerCase());
        if (match != null && i < _anchors.length) {
          // 值是毫米，转换为米
          distances[_anchors[i].id] = double.parse(match.group(1)!) / 1000.0;
        }
      }

      if (distances.isNotEmpty) {
        // 使用三边定位计算位置
        final pos = _trilaterate(distances);
        if (pos != null) {
          return UwbTag(
            id: '標籤0',
            x: pos['x']!,
            y: pos['y']!,
            z: pos['z'] ?? 0.0,
            anchorDistances: distances,
          );
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 解析 x: y: 格式
  UwbTag? _parseXYFormat(String data) {
    try {
      final xMatch =
          RegExp(r'x[:\s]*([\d.-]+)', caseSensitive: false).firstMatch(data);
      final yMatch =
          RegExp(r'y[:\s]*([\d.-]+)', caseSensitive: false).firstMatch(data);
      final zMatch =
          RegExp(r'z[:\s]*([\d.-]+)', caseSensitive: false).firstMatch(data);

      if (xMatch != null && yMatch != null) {
        final x = double.parse(xMatch.group(1)!);
        final y = double.parse(yMatch.group(1)!);
        final z = zMatch != null ? double.parse(zMatch.group(1)!) : 0.0;

        return _createTagWithDistances(x, y, z);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 解析空格分隔的数字格式
  UwbTag? _parseSpaceSeparatedFormat(String data) {
    try {
      final numbers =
          data.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();

      if (numbers.length >= 2) {
        final x = double.tryParse(numbers[0]);
        final y = double.tryParse(numbers[1]);
        final z = numbers.length > 2 ? double.tryParse(numbers[2]) : 0.0;

        if (x != null && y != null) {
          return _createTagWithDistances(x, y, z ?? 0.0);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 创建标签并计算到各基站的距离
  UwbTag _createTagWithDistances(double x, double y, double z) {
    final Map<String, double> distances = {};
    for (var anchor in _anchors) {
      final double dx = x - anchor.x;
      final double dy = y - anchor.y;
      final double dz = z - anchor.z;
      final double distance = sqrt(dx * dx + dy * dy + dz * dz);
      distances[anchor.id] = double.parse(distance.toStringAsFixed(3));
    }

    return UwbTag(
      id: '標籤0',
      x: x,
      y: y,
      z: z,
      anchorDistances: distances,
    );
  }

  // 简单的三边定位
  Map<String, double>? _trilaterate(Map<String, double> distances) {
    if (_anchors.length < 3 || distances.length < 3) return null;

    try {
      // 获取前三个基站及其距离
      final a0 = _anchors[0];
      final a1 = _anchors[1];
      final a2 = _anchors[2];

      final d0 = distances[a0.id];
      final d1 = distances[a1.id];
      final d2 = distances[a2.id];

      if (d0 == null || d1 == null || d2 == null) return null;

      // 简化的2D三边定位
      final A = 2 * (a1.x - a0.x);
      final B = 2 * (a1.y - a0.y);
      final C = d0 * d0 -
          d1 * d1 -
          a0.x * a0.x +
          a1.x * a1.x -
          a0.y * a0.y +
          a1.y * a1.y;
      final D = 2 * (a2.x - a1.x);
      final E = 2 * (a2.y - a1.y);
      final F = d1 * d1 -
          d2 * d2 -
          a1.x * a1.x +
          a2.x * a2.x -
          a1.y * a1.y +
          a2.y * a2.y;

      final denom = A * E - B * D;
      if (denom.abs() < 0.0001) return null;

      final x = (C * E - B * F) / denom;
      final y = (A * F - C * D) / denom;

      return {'x': x, 'y': y, 'z': 0.0};
    } catch (e) {
      return null;
    }
  }

  // 解析 JSON 格式
  UwbTag? _parseJsonFormat(String data) {
    try {
      // 简单解析，不使用 dart:convert 以避免依赖问题
      final x = _extractJsonNumber(data, 'x');
      final y = _extractJsonNumber(data, 'y');
      final z = _extractJsonNumber(data, 'z');

      if (x == null || y == null) return null;

      final Map<String, double> distances = {};
      for (int i = 0; i < 8; i++) {
        final d = _extractJsonNumber(data, 'd$i');
        if (d != null && i < _anchors.length) {
          distances[_anchors[i].id] = d;
        }
      }

      return UwbTag(
        id: '標籤0',
        x: x,
        y: y,
        z: z ?? 0.0,
        anchorDistances: distances,
      );
    } catch (e) {
      return null;
    }
  }

  double? _extractJsonNumber(String json, String key) {
    final regex = RegExp('"$key"\\s*:\\s*([\\d.-]+)');
    final match = regex.firstMatch(json);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  // 解析 TAG 格式: "TAG:0 X:4.533 Y:1.868 Z:0.000 Q:95"
  UwbTag? _parseTagFormat(String data) {
    try {
      final xMatch = RegExp(r'X:([\d.-]+)').firstMatch(data);
      final yMatch = RegExp(r'Y:([\d.-]+)').firstMatch(data);
      final zMatch = RegExp(r'Z:([\d.-]+)').firstMatch(data);

      if (xMatch == null || yMatch == null) return null;

      final x = double.parse(xMatch.group(1)!);
      final y = double.parse(yMatch.group(1)!);
      final z = zMatch != null ? double.parse(zMatch.group(1)!) : 0.0;

      // 计算到各基站的距离
      final Map<String, double> distances = {};
      for (var anchor in _anchors) {
        final double dx = x - anchor.x;
        final double dy = y - anchor.y;
        final double dz = z - anchor.z;
        final double distance = sqrt(dx * dx + dy * dy + dz * dz);
        distances[anchor.id] = double.parse(distance.toStringAsFixed(3));
      }

      return UwbTag(
        id: '標籤0',
        x: x,
        y: y,
        z: z,
        anchorDistances: distances,
      );
    } catch (e) {
      return null;
    }
  }

  // 解析 mc 格式
  UwbTag? _parseMcFormat(String data) {
    try {
      final parts = data.split(' ');
      if (parts.length < 10 || parts[0] != 'mc') return null;

      // 解析距离数据 (十六进制,单位毫米)
      final List<double> distances = [];
      for (int i = 2; i < 6 && i < parts.length; i++) {
        final int mm = int.parse(parts[i], radix: 16);
        distances.add(mm / 1000.0);
      }

      // 解析坐标 (十六进制)
      final int xMm = int.parse(parts[6], radix: 16);
      final int yMm = int.parse(parts[7], radix: 16);
      final int zMm = int.parse(parts[8], radix: 16);

      final Map<String, double> anchorDistances = {};
      for (int i = 0; i < distances.length && i < _anchors.length; i++) {
        anchorDistances[_anchors[i].id] = distances[i];
      }

      return UwbTag(
        id: '標籤0',
        x: xMm / 1000.0,
        y: yMm / 1000.0,
        z: zMm / 1000.0,
        anchorDistances: anchorDistances,
      );
    } catch (e) {
      return null;
    }
  }

  // 解析简单格式: "4.533,1.868,0.000" 或带距离 "4.533,1.868,0.000,5.07,3.104,4.118,2.964"
  UwbTag? _parseSimpleFormat(String data) {
    try {
      final parts =
          data.split(',').map((s) => double.tryParse(s.trim())).toList();

      if (parts.length < 2 || parts[0] == null || parts[1] == null) return null;

      final x = parts[0]!;
      final y = parts[1]!;
      final z = parts.length > 2 ? (parts[2] ?? 0.0) : 0.0;

      final Map<String, double> distances = {};
      for (int i = 3; i < parts.length && (i - 3) < _anchors.length; i++) {
        if (parts[i] != null) {
          distances[_anchors[i - 3].id] = parts[i]!;
        }
      }

      // 如果没有距离数据，计算距离
      if (distances.isEmpty) {
        for (var anchor in _anchors) {
          final double dx = x - anchor.x;
          final double dy = y - anchor.y;
          final double dz = z - anchor.z;
          final double distance = sqrt(dx * dx + dy * dy + dz * dz);
          distances[anchor.id] = double.parse(distance.toStringAsFixed(3));
        }
      }

      return UwbTag(
        id: '標籤0',
        x: x,
        y: y,
        z: z,
        anchorDistances: distances,
      );
    } catch (e) {
      return null;
    }
  }

  // 三边定位算法 (基于TOA)
  Map<String, double>? calculatePosition(Map<String, double> distances) {
    if (_anchors.length < 3 || distances.length < 3) return null;

    try {
      // 使用最小二乘法进行三边定位
      // 这里简化为使用前3个基站
      final a0 = _anchors[0];
      final a1 = _anchors[1];
      final a2 = _anchors[2];

      final double d0 = distances[a0.id] ?? 0;
      final double d1 = distances[a1.id] ?? 0;
      final double d2 = distances[a2.id] ?? 0;

      // 计算位置 (2D简化版)
      final double A = 2 * (a1.x - a0.x);
      final double B = 2 * (a1.y - a0.y);
      final double C = d0 * d0 -
          d1 * d1 -
          a0.x * a0.x +
          a1.x * a1.x -
          a0.y * a0.y +
          a1.y * a1.y;

      final double D = 2 * (a2.x - a1.x);
      final double E = 2 * (a2.y - a1.y);
      final double F = d1 * d1 -
          d2 * d2 -
          a1.x * a1.x +
          a2.x * a2.x -
          a1.y * a1.y +
          a2.y * a2.y;

      final double denom = A * E - B * D;
      if (denom.abs() < 0.0001) return null;

      final double x = (C * E - F * B) / denom;
      final double y = (A * F - D * C) / denom;

      return {'x': x, 'y': y, 'z': 0.0};
    } catch (e) {
      debugPrint('定位计算失败: $e');
      return null;
    }
  }

  // 获取区域范围
  double getAreaWidth() {
    if (_anchors.isEmpty) return 10.0;
    final double maxX = _anchors.map((a) => a.x).reduce(max);
    return maxX + 1.0;
  }

  double getAreaHeight() {
    if (_anchors.isEmpty) return 10.0;
    final double maxY = _anchors.map((a) => a.y).reduce(max);
    return maxY + 1.0;
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}
