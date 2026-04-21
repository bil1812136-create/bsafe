import 'dart:typed_data';

typedef VoidCallback = void Function();

class UsbDeviceInfo {
  final String deviceName;
  final int vid;
  final int pid;
  final String? productName;
  final String? manufacturerName;
  final dynamic rawDevice;

  UsbDeviceInfo({
    required this.deviceName,
    required this.vid,
    required this.pid,
    this.productName,
    this.manufacturerName,
    this.rawDevice,
  });

  String get displayName => deviceName;
}

class MobileSerialService {
  static final MobileSerialService _instance = MobileSerialService._internal();
  factory MobileSerialService() => _instance;
  MobileSerialService._internal();

  VoidCallback? onDeviceConnected;
  VoidCallback? onDeviceDisconnected;

  bool get isConnected => false;
  String? get connectedDeviceName => null;

  Stream<String> get dataStream => const Stream<String>.empty();
  Stream<Uint8List> get rawDataStream => const Stream<Uint8List>.empty();

  Future<List<UsbDeviceInfo>> getAvailableDevices() async => const [];

  Future<List<String>> getAvailablePorts() async => const [];

  Future<bool> connect(dynamic device, {int baudRate = 115200}) async => false;

  Future<bool> autoConnect({int baudRate = 115200}) async => false;

  Future<bool> connectByIndex(int index, {int baudRate = 115200}) async =>
      false;

  Future<void> disconnect() async {}

  Future<bool> write(String data) async => false;

  void startUsbEventListening() {}

  void stopUsbEventListening() {}

  void dispose() {}
}
