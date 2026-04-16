import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class SerialDataPacket {
  final Uint8List rawBytes;
  final String text;

  SerialDataPacket(this.rawBytes, this.text);
}

class DesktopSerialService {
  static final DesktopSerialService _instance =
      DesktopSerialService._internal();
  factory DesktopSerialService() => _instance;
  DesktopSerialService._internal();

  SerialPort? _port;
  SerialPortReader? _reader;
  bool _isConnected = false;

  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  final StreamController<Uint8List> _rawDataController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get rawDataStream => _rawDataController.stream;

  bool get isConnected => _isConnected;

  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  Future<bool> connect(String portName, {int baudRate = 115200}) async {
    try {

      if (_isConnected) {
        await disconnect();
      }

      _port = SerialPort(portName);

      final config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      config.setFlowControl(SerialPortFlowControl.none);

      _port!.config = config;

      if (!_port!.openReadWrite()) {
        final error = SerialPort.lastError;
        debugPrint('无法打开串口 $portName: ${error?.message}');
        return false;
      }

      _isConnected = true;

      _startReading();

      debugPrint('串口 $portName 连接成功 (波特率: $baudRate)');
      return true;
    } catch (e) {
      debugPrint('串口连接失败: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<bool> autoConnect({int baudRate = 115200}) async {
    final ports = getAvailablePorts();

    if (ports.isEmpty) {
      debugPrint('未找到可用的串口设备');
      return false;
    }

    debugPrint('找到 ${ports.length} 个串口: $ports');

    for (final port in ports) {
      debugPrint('尝试连接: $port');
      if (await connect(port, baudRate: baudRate)) {
        return true;
      }
    }

    return false;
  }

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

  int _totalBytesReceived = 0;

  void _startReading() {
    if (_port == null || !_isConnected) return;

    try {
      _reader = SerialPortReader(_port!);
      List<int> byteBuffer = [];

      _reader!.stream.listen(
        (Uint8List data) {
          try {
            _totalBytesReceived += data.length;

            if (_totalBytesReceived % 500 < data.length) {
              debugPrint(
                  '[串口] 已接收 $_totalBytesReceived 字節, 當前塊: ${data.length} 字節');
            }

            byteBuffer.addAll(data);

            _rawDataController.add(data);

            while (byteBuffer.length >= 100) {

              final firstCmdM = _findCmdMStart(byteBuffer);
              if (firstCmdM < 0) {

                if (byteBuffer.length > 200) {
                  byteBuffer = byteBuffer.sublist(byteBuffer.length - 100);
                }
                break;
              }

              if (firstCmdM > 0) {
                byteBuffer = byteBuffer.sublist(firstCmdM);
              }

              final secondCmdM = _findCmdMStart(byteBuffer.sublist(7));
              int packetEnd;

              if (secondCmdM > 0) {

                packetEnd = 7 + secondCmdM;
              } else if (byteBuffer.length >= 100) {

                packetEnd = 100;
              } else {

                break;
              }

              final packetBytes =
                  Uint8List.fromList(byteBuffer.sublist(0, packetEnd));
              byteBuffer = byteBuffer.sublist(packetEnd);

              if (packetBytes.length >= 20) {

                final hexData = packetBytes
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(' ');
                _dataController.add('RAWBIN:${packetBytes.length}:$hexData');
              }
            }

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

  bool _isCmdMPacket(Uint8List data) {

    if (data.length >= 7) {
      return data[0] == 0x43 &&
          data[1] == 0x6d &&
          data[2] == 0x64 &&
          data[3] == 0x4d;
    }
    return false;
  }

  int _findCmdMStart(List<int> buffer) {

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

  void dispose() {
    disconnect();
    _dataController.close();
    _rawDataController.close();
  }
}
