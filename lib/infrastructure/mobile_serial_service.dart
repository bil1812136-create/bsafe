import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

class UsbDeviceInfo {
  final String deviceName;
  final int vid;
  final int pid;
  final String? productName;
  final String? manufacturerName;
  final UsbDevice rawDevice;

  UsbDeviceInfo({
    required this.deviceName,
    required this.vid,
    required this.pid,
    this.productName,
    this.manufacturerName,
    required this.rawDevice,
  });

  String get displayName {
    if (productName != null && productName!.isNotEmpty) {
      return '$productName ($deviceName)';
    }

    if (vid == 0x1A86 && pid == 0x7523) return 'CH340 ($deviceName)';
    if (vid == 0x10C4 && pid == 0xEA60) return 'CP2102 ($deviceName)';
    if (vid == 0x0403 && pid == 0x6001) return 'FTDI ($deviceName)';
    if (vid == 0x2341) return 'Arduino ($deviceName)';
    return 'USB Serial ($deviceName)';
  }

  @override
  String toString() =>
      'UsbDeviceInfo(name: $deviceName, vid: 0x${vid.toRadixString(16)}, pid: 0x${pid.toRadixString(16)})';
}

class MobileSerialService {
  static final MobileSerialService _instance = MobileSerialService._internal();
  factory MobileSerialService() => _instance;
  MobileSerialService._internal();

  UsbPort? _port;
  UsbDevice? _device;
  bool _isConnected = false;

  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  final StreamController<Uint8List> _rawDataController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get rawDataStream => _rawDataController.stream;

  StreamSubscription? _usbEventSubscription;

  VoidCallback? onDeviceConnected;
  VoidCallback? onDeviceDisconnected;

  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _device?.deviceName;

  Future<List<UsbDeviceInfo>> getAvailableDevices() async {
    try {
      final devices = await UsbSerial.listDevices();
      debugPrint('[USB] 發現 ${devices.length} 個 USB 設備');

      return devices.map((d) {
        debugPrint(
            '[USB] 設備: ${d.deviceName}, VID: 0x${d.vid?.toRadixString(16)}, PID: 0x${d.pid?.toRadixString(16)}, Product: ${d.productName}');
        return UsbDeviceInfo(
          deviceName: d.deviceName,
          vid: d.vid ?? 0,
          pid: d.pid ?? 0,
          productName: d.productName,
          manufacturerName: d.manufacturerName,
          rawDevice: d,
        );
      }).toList();
    } catch (e) {
      debugPrint('[USB] 獲取設備列表失敗: $e');
      return [];
    }
  }

  Future<List<String>> getAvailablePorts() async {
    final devices = await getAvailableDevices();
    return devices.map((d) => d.displayName).toList();
  }

  Future<bool> connect(UsbDevice device, {int baudRate = 115200}) async {
    try {

      if (_isConnected) {
        await disconnect();
      }

      debugPrint('[USB] 嘗試連接: ${device.deviceName}');

      _port = await device.create();
      if (_port == null) {
        debugPrint('[USB] 無法創建端口');
        return false;
      }

      final openResult = await _port!.open();
      if (!openResult) {
        debugPrint('[USB] 無法打開端口');
        _port = null;
        return false;
      }

      await _port!.setDTR(true);
      await _port!.setRTS(true);
      _port!.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _device = device;
      _isConnected = true;

      _startReading();

      debugPrint(
          '[USB] 連接成功: ${device.deviceName} (波特率: $baudRate)');
      return true;
    } catch (e) {
      debugPrint('[USB] 連接失敗: $e');
      _isConnected = false;
      _port = null;
      return false;
    }
  }

  Future<bool> autoConnect({int baudRate = 115200}) async {
    final devices = await getAvailableDevices();

    if (devices.isEmpty) {
      debugPrint('[USB] 未找到可用的 USB 串口設備');
      return false;
    }

    debugPrint('[USB] 找到 ${devices.length} 個設備，嘗試連接第一個');

    UsbDeviceInfo? preferredDevice;
    for (final d in devices) {
      if (d.vid == 0x1A86 || d.vid == 0x10C4) {
        preferredDevice = d;
        break;
      }
    }

    final targetDevice = preferredDevice ?? devices.first;
    return connect(targetDevice.rawDevice, baudRate: baudRate);
  }

  Future<bool> connectByIndex(int index, {int baudRate = 115200}) async {
    final devices = await getAvailableDevices();
    if (index < 0 || index >= devices.length) return false;
    return connect(devices[index].rawDevice, baudRate: baudRate);
  }

  Future<void> disconnect() async {
    _isConnected = false;

    try {
      await _port?.close();
      _port = null;
      _device = null;
      debugPrint('[USB] 已斷開連接');
    } catch (e) {
      debugPrint('[USB] 斷開連接錯誤: $e');
    }
  }

  int _totalBytesReceived = 0;

  void _startReading() {
    if (_port == null || !_isConnected) return;

    try {
      List<int> byteBuffer = [];

      _port!.inputStream?.listen(
        (Uint8List data) {
          try {
            _totalBytesReceived += data.length;

            if (_totalBytesReceived % 500 < data.length) {
              debugPrint(
                  '[USB] 已接收 $_totalBytesReceived 字節, 當前塊: ${data.length} 字節');
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
            debugPrint('[USB] 數據解析錯誤: $e');
          }
        },
        onError: (error) {
          debugPrint('[USB] 讀取錯誤: $error');
          _isConnected = false;
          onDeviceDisconnected?.call();
        },
        onDone: () {
          debugPrint('[USB] 讀取結束');
          _isConnected = false;
          onDeviceDisconnected?.call();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[USB] 開始讀取數據失敗: $e');
      _isConnected = false;
    }
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
      debugPrint('[USB] 串口未連接');
      return false;
    }

    try {
      final bytes = utf8.encode(data);
      await _port!.write(Uint8List.fromList(bytes));
      return true;
    } catch (e) {
      debugPrint('[USB] 發送數據失敗: $e');
      return false;
    }
  }

  void startUsbEventListening() {
    _usbEventSubscription?.cancel();
    _usbEventSubscription =
        UsbSerial.usbEventStream?.listen((UsbEvent event) {
      debugPrint('[USB] 事件: ${event.event}, 設備: ${event.device?.deviceName}');
      if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
        onDeviceConnected?.call();
      } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        if (_device != null &&
            event.device?.deviceName == _device!.deviceName) {
          _isConnected = false;
          _port = null;
          _device = null;
        }
        onDeviceDisconnected?.call();
      }
    });
  }

  void stopUsbEventListening() {
    _usbEventSubscription?.cancel();
    _usbEventSubscription = null;
  }

  void dispose() {
    disconnect();
    stopUsbEventListening();
    _dataController.close();
    _rawDataController.close();
  }
}
