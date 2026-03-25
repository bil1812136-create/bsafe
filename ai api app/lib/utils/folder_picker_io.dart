import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:ai_api_classifier/utils/picked_image_data.dart';

Future<List<PickedImageData>> pickImagesFromFolder() async {
  final dir = await FilePicker.platform.getDirectoryPath();
  if (dir == null || dir.isEmpty) return <PickedImageData>[];

  final directory = Directory(dir);
  if (!await directory.exists()) return <PickedImageData>[];

  final exts = <String>{'.jpg', '.jpeg', '.png', '.webp', '.bmp'};
  final files = directory
      .listSync(recursive: false)
      .whereType<File>()
      .where((f) => exts.contains(_ext(f.path).toLowerCase()))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final result = <PickedImageData>[];
  for (final file in files) {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      result
          .add(PickedImageData(name: file.uri.pathSegments.last, bytes: bytes));
    } catch (_) {
      // Ignore unreadable files and continue processing others.
    }
  }

  return result;
}

String _ext(String path) {
  final i = path.lastIndexOf('.');
  if (i < 0) return '';
  return path.substring(i);
}
