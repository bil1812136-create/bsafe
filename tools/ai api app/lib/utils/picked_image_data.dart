import 'dart:typed_data';

class PickedImageData {
  PickedImageData({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
