import 'dart:typed_data';

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

  bool get isConnected => false;

  Stream<String> get dataStream => const Stream<String>.empty();
  Stream<Uint8List> get rawDataStream => const Stream<Uint8List>.empty();

  List<String> getAvailablePorts() => const [];

  Future<bool> connect(String portName, {int baudRate = 115200}) async => false;

  Future<bool> autoConnect({int baudRate = 115200}) async => false;

  Future<void> disconnect() async {}

  Future<bool> write(String data) async => false;

  void dispose() {}
}
