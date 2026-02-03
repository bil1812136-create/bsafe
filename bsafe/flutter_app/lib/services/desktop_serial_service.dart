import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// 串口数据包 - 包含原始字节和解析后的字符串
class SerialDataPacket {
  final Uint8List rawBytes;
  final String text;

  SerialDataPacket(this.rawBytes, this.text);
}

/// 桌面平台串口服务
/// 用于 Windows/Linux/macOS 连接安信可 UWB BU04 设备
class DesktopSerialService {
  static final DesktopSerialService _instance =
      DesktopSerialService._internal();
  factory DesktopSerialService() => _instance;
  DesktopSerialService._internal();

  SerialPort? _port;
  SerialPortReader? _reader;
  bool _isConnected = false;

  // 字符串流 (向后兼容)
  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  // 原始字节流 (用于二进制协议解析)
  final StreamController<Uint8List> _rawDataController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get rawDataStream => _rawDataController.stream;

  bool get isConnected => _isConnected;

  /// 获取所有可用的串口列表
  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  /// 连接指定的串口
  Future<bool> connect(String portName, {int baudRate = 115200}) async {
    try {
      // 断开现有连接
      if (_isConnected) {
        await disconnect();
      }

      _port = SerialPort(portName);

      // 配置串口参数
      final config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      config.setFlowControl(SerialPortFlowControl.none);

      _port!.config = config;

      // 打开串口
      if (!_port!.openReadWrite()) {
        final error = SerialPort.lastError;
        debugPrint('无法打开串口 $portName: ${error?.message}');
        return false;
      }

      _isConnected = true;

      // 开始读取数据
      _startReading();

      debugPrint('串口 $portName 连接成功 (波特率: $baudRate)');
      return true;
    } catch (e) {
      debugPrint('串口连接失败: $e');
      _isConnected = false;
      return false;
    }
  }

  /// 自动连接第一个可用的串口（通常是 BU04 设备）
  Future<bool> autoConnect({int baudRate = 115200}) async {
    final ports = getAvailablePorts();

    if (ports.isEmpty) {
      debugPrint('未找到可用的串口设备');
      return false;
    }

    debugPrint('找到 ${ports.length} 个串口: $ports');

    // 尝试连接第一个串口
    for (final port in ports) {
      debugPrint('尝试连接: $port');
      if (await connect(port, baudRate: baudRate)) {
        return true;
      }
    }

    return false;
  }

  /// 断开串口连接
  Future<void> disconnect() async {
    _isConnected = false;

    try {
      _reader?.close();
      _reader = null;

      _port?.close();
      _port?.dispose();
      _port = null;

      debugPrint('串口已断开');
    } catch (e) {
      debugPrint('断开连接错误: $e');
    }
  }

  // 記錄收到的原始字節數 (用於調試)
  int _totalBytesReceived = 0;

  /// 开始读取串口数据
  void _startReading() {
    if (_port == null || !_isConnected) return;

    try {
      _reader = SerialPortReader(_port!);
      List<int> byteBuffer = [];

      _reader!.stream.listen(
        (Uint8List data) {
          try {
            _totalBytesReceived += data.length;

            // 調試：每收到一些數據就打印
            if (_totalBytesReceived % 500 < data.length) {
              debugPrint(
                  '[串口] 已接收 $_totalBytesReceived 字節, 當前塊: ${data.length} 字節');
            }

            // 添加新数据到缓冲区
            byteBuffer.addAll(data);

            // 同时发送原始数据流
            _rawDataController.add(data);

            // BU04 TWR 數據格式: "CmdM:4[" + 91 bytes data + "]"
            // 固定數據包長度約 100 字節 (7 + 91 + 1 + 換行符)
            // 使用兩個連續 CmdM 之間的數據作為一個完整數據包
            while (byteBuffer.length >= 100) {
              // 找第一個 CmdM 開頭
              final firstCmdM = _findCmdMStart(byteBuffer);
              if (firstCmdM < 0) {
                // 沒有找到 CmdM，丟棄部分緩衝區
                if (byteBuffer.length > 200) {
                  byteBuffer = byteBuffer.sublist(byteBuffer.length - 100);
                }
                break;
              }

              // 丟棄 CmdM 之前的垃圾數據
              if (firstCmdM > 0) {
                byteBuffer = byteBuffer.sublist(firstCmdM);
              }

              // 找下一個 CmdM 或使用固定長度
              final secondCmdM = _findCmdMStart(byteBuffer.sublist(7));
              int packetEnd;

              if (secondCmdM > 0) {
                // 找到下一個 CmdM，當前數據包到這裡結束
                packetEnd = 7 + secondCmdM;
              } else if (byteBuffer.length >= 100) {
                // 沒找到下一個 CmdM，使用固定長度（約100字節）
                packetEnd = 100;
              } else {
                // 數據不足，等待更多數據
                break;
              }

              // 提取數據包
              final packetBytes =
                  Uint8List.fromList(byteBuffer.sublist(0, packetEnd));
              byteBuffer = byteBuffer.sublist(packetEnd);

              // 只處理足夠長的數據包（至少包含距離數據）
              if (packetBytes.length >= 20) {
                // 發送 RAWBIN 格式
                final hexData = packetBytes
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(' ');
                _dataController.add('RAWBIN:${packetBytes.length}:$hexData');
              }
            }

            // 防止缓冲区过大
            if (byteBuffer.length > 500) {
              byteBuffer = byteBuffer.sublist(byteBuffer.length - 200);
            }
          } catch (e) {
            debugPrint('数据解析错误: $e');
          }
        },
        onError: (error) {
          debugPrint('串口读取错误: $error');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('串口读取结束');
          _isConnected = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('开始读取数据失败: $e');
      _isConnected = false;
    }
  }

  /// 检查是否是 CmdM 二进制数据包
  bool _isCmdMPacket(Uint8List data) {
    // CmdM 的 ASCII: 43 6d 64 4d
    if (data.length >= 7) {
      return data[0] == 0x43 && // C
          data[1] == 0x6d && // m
          data[2] == 0x64 && // d
          data[3] == 0x4d; // M
    }
    return false;
  }

  /// 在緩衝區中查找 CmdM 數據包的開始位置
  int _findCmdMStart(List<int> buffer) {
    // 查找 "CmdM" 標識 (43 6d 64 4d)
    for (int i = 0; i < buffer.length - 7; i++) {
      if (buffer[i] == 0x43 &&
          buffer[i + 1] == 0x6d &&
          buffer[i + 2] == 0x64 &&
          buffer[i + 3] == 0x4d) {
        return i;
      }
    }
    return -1;
  }

  /// 发送数据到串口
  Future<bool> write(String data) async {
    if (_port == null || !_isConnected) {
      debugPrint('串口未连接');
      return false;
    }

    try {
      final bytes = utf8.encode(data);
      final written = _port!.write(Uint8List.fromList(bytes));
      return written == bytes.length;
    } catch (e) {
      debugPrint('发送数据失败: $e');
      return false;
    }
  }

  /// 清理资源
  void dispose() {
    disconnect();
    _dataController.close();
    _rawDataController.close();
  }
}
