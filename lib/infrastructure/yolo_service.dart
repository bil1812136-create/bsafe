import 'dart:convert';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class YoloDetection {
  final String className;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  YoloDetection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, double> toPixelBox(double imgWidth, double imgHeight) {
    return {
      'left': (x - width / 2) * imgWidth,
      'top': (y - height / 2) * imgHeight,
      'right': (x + width / 2) * imgWidth,
      'bottom': (y + height / 2) * imgHeight,
      'width': width * imgWidth,
      'height': height * imgHeight,
    };
  }

  Map<String, dynamic> toJson() => {
        'class': className,
        'confidence': confidence,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

class YoloService {
  static YoloService? _instance;
  Interpreter? _interpreter;
  bool _isLoaded = false;
  bool _isLoading = false;
  List<String> _classNames = [];

  YoloService._();

  static YoloService get instance {
    _instance ??= YoloService._();
    return _instance!;
  }

  static bool get isSupported => !kIsWeb;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  Future<bool> loadModel(
      {String modelPath = 'assets/model/yolo.tflite'}) async {
    if (!isSupported) return false;
    if (_isLoaded) return true;
    if (_isLoading) return false;
    _isLoading = true;
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(modelPath, options: options);
      _interpreter!.allocateTensors();
      _classNames = await _loadClassNames(modelPath);
      _isLoaded = true;
      debugPrint('YOLO: 模型載入成功 (tflite_flutter CPU, 4 threads)');
      debugPrint('YOLO: classes = $_classNames');
    } catch (e) {
      debugPrint('YOLO: 模型載入失敗: $e');
      _interpreter = null;
      _isLoaded = false;
    } finally {
      _isLoading = false;
    }
    return _isLoaded;
  }

  Future<List<YoloDetection>> detect(Uint8List imageBytes,
      {double confidenceThreshold = 0.25}) async {
    if (!_isLoaded) {
      final loaded = await loadModel();
      if (!loaded) return [];
    }
    final interp = _interpreter;
    if (interp == null) return [];
    try {
      final inputTensor = await _preprocessImage(imageBytes);
      if (inputTensor == null) return [];

      final numOutputs = interp.getOutputTensors().length;
      final outputMap = <int, List>{};
      for (int i = 0; i < numOutputs; i++) {
        final shape = interp.getOutputTensor(i).shape;
        debugPrint('YOLO: output[$i] shape = $shape');
        outputMap[i] = _buildOutputBuffer(shape);
      }

      interp.runForMultipleInputs([inputTensor], outputMap);

      final detShape = interp.getOutputTensor(0).shape;
      final detections = _parseDetections(
          outputMap[0]!, detShape, confidenceThreshold, _classNames);
      debugPrint('YOLO: 偵測到 ${detections.length} 個物件');
      return detections;
    } catch (e, stack) {
      debugPrint('YOLO: 偵測失敗: $e');
      debugPrint('YOLO: stack: $stack');
      return [];
    }
  }

  static List _buildOutputBuffer(List<int> shape) {
    if (shape.length == 4) {
      return List.generate(
          shape[0],
          (_) => List.generate(
              shape[1],
              (_) =>
                  List.generate(shape[2], (_) => List.filled(shape[3], 0.0))));
    }
    if (shape.length == 3) {
      return List.generate(shape[0],
          (_) => List.generate(shape[1], (_) => List.filled(shape[2], 0.0)));
    }
    if (shape.length == 2) {
      return List.generate(shape[0], (_) => List.filled(shape[1], 0.0));
    }
    return List.filled(shape[0], 0.0);
  }

  static Future<List<String>> _loadClassNames(String modelPath) async {
    try {
      final bytes = await rootBundle.load(modelPath);
      final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());
      final metaFile = archive.findFile('metadata.json');
      if (metaFile == null) return [];
      final json = jsonDecode(utf8.decode(metaFile.content as List<int>));
      final names = json['names'] as Map<String, dynamic>?;
      if (names == null) return [];
      final maxIdx = names.keys.map(int.parse).fold(0, (a, b) => a > b ? a : b);
      final list = List<String>.filled(maxIdx + 1, 'unknown');
      names.forEach((k, v) => list[int.parse(k)] = v.toString());
      return list;
    } catch (e) {
      debugPrint('YOLO: 無法載入類別名稱: $e');
      return [];
    }
  }

  static List<YoloDetection> _parseDetections(dynamic buffer, List<int> shape,
      double threshold, List<String> classNames) {
    if (shape.length != 3 || shape[0] < 1) return [];
    final rows = (buffer as List)[0] as List;
    final numRows = shape[1];
    final numCols = shape[2];
    final detections = <YoloDetection>[];

    if (numCols >= 37) {
      // YOLO26-seg end2end one-to-one head: [x1,y1,x2,y2, cls*nc, mask*32]
      // nc = numCols - 36 (4 bbox + nc class scores + 32 mask coefficients)
      final nc = numCols - 36;
      for (int i = 0; i < numRows; i++) {
        final row = rows[i] as List;
        double maxScore = -1;
        int classId = 0;
        for (int c = 0; c < nc; c++) {
          final s = (row[4 + c] as num).toDouble();
          if (s > maxScore) {
            maxScore = s;
            classId = c;
          }
        }
        if (maxScore < threshold) continue;
        final x1 = (row[0] as num).toDouble();
        final y1 = (row[1] as num).toDouble();
        final x2 = (row[2] as num).toDouble();
        final y2 = (row[3] as num).toDouble();
        final w = x2 - x1;
        final h = y2 - y1;
        if (w <= 0 || h <= 0) continue;
        detections.add(YoloDetection(
          className: classId < classNames.length
              ? classNames[classId]
              : 'class_$classId',
          confidence: maxScore,
          x: (x1 + x2) / 2,
          y: (y1 + y2) / 2,
          width: w,
          height: h,
        ));
      }
    } else if (numCols >= 6) {
      // Legacy post-processed format: [x1,y1,x2,y2, conf, class_id, ...]
      for (int i = 0; i < numRows; i++) {
        final row = rows[i] as List;
        final conf = (row[4] as num).toDouble();
        if (conf < threshold) continue;
        final x1 = (row[0] as num).toDouble();
        final y1 = (row[1] as num).toDouble();
        final x2 = (row[2] as num).toDouble();
        final y2 = (row[3] as num).toDouble();
        final classId = (row[5] as num).toInt();
        final w = x2 - x1;
        final h = y2 - y1;
        if (w <= 0 || h <= 0) continue;
        detections.add(YoloDetection(
          className: classId < classNames.length
              ? classNames[classId]
              : 'class_$classId',
          confidence: conf,
          x: (x1 + x2) / 2,
          y: (y1 + y2) / 2,
          width: w,
          height: h,
        ));
      }
    } else if (numCols == 5) {
      for (int i = 0; i < numRows; i++) {
        final row = rows[i] as List;
        final conf = (row[4] as num).toDouble();
        if (conf < threshold) continue;
        final w = (row[2] as num).toDouble();
        final h = (row[3] as num).toDouble();
        if (w <= 0 || h <= 0) continue;
        detections.add(YoloDetection(
          className: classNames.isNotEmpty ? classNames[0] : 'class_0',
          confidence: conf,
          x: (row[0] as num).toDouble(),
          y: (row[1] as num).toDouble(),
          width: w,
          height: h,
        ));
      }
    } else if (numRows >= 5) {
      const numMaskCoeffs = 32;
      final numClasses = numRows - 4 - numMaskCoeffs;
      final classEnd = (numClasses > 0) ? 4 + numClasses : numRows;
      for (int i = 0; i < numCols; i++) {
        double maxScore = 0;
        int classId = 0;
        for (int c = 4; c < classEnd; c++) {
          final s = ((rows[c] as List)[i] as num).toDouble();
          if (s > maxScore) {
            maxScore = s;
            classId = c - 4;
          }
        }
        if (maxScore < threshold) continue;
        final cx = ((rows[0] as List)[i] as num).toDouble();
        final cy = ((rows[1] as List)[i] as num).toDouble();
        final w = ((rows[2] as List)[i] as num).toDouble();
        final h = ((rows[3] as List)[i] as num).toDouble();
        if (w <= 0 || h <= 0) continue;
        detections.add(YoloDetection(
          className: classId < classNames.length
              ? classNames[classId]
              : 'class_$classId',
          confidence: maxScore,
          x: cx,
          y: cy,
          width: w,
          height: h,
        ));
      }
    }
    return detections;
  }

  Future<dynamic> _preprocessImage(Uint8List imageBytes) async {
    const int size = 640;
    try {
      final codec = await ui.instantiateImageCodec(imageBytes,
          targetWidth: size, targetHeight: size);
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      codec.dispose();
      if (byteData == null) return null;

      final pixels = byteData.buffer.asUint8List();
      return List.generate(
        1,
        (_) => List.generate(
          size,
          (h) => List.generate(
            size,
            (w) {
              final idx = (h * size + w) * 4;
              return [
                pixels[idx + 0] / 255.0,
                pixels[idx + 1] / 255.0,
                pixels[idx + 2] / 255.0,
              ];
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('YOLO preprocess error: $e');
      return null;
    }
  }

  static Map<String, dynamic> toSafetyAnalysis(List<YoloDetection> detections) {
    if (detections.isEmpty) {
      return {
        'risk_level': 'low',
        'risk_score': 10,
        'analysis': 'YOLO 偵測完成，未發現明顯物件異常。',
        'recommendations': ['建議進一步人工檢查確認'],
        'detections': [],
        'detection_count': 0,
      };
    }

    final detectedItems = detections
        .map((d) =>
            '${d.className} (${(d.confidence * 100).toStringAsFixed(0)}%)')
        .toList();

    int riskScore = 10;
    riskScore += (detections.length * 5).clamp(0, 60);
    riskScore = riskScore.clamp(0, 100);

    String riskLevel = 'low';
    if (riskScore >= 70) {
      riskLevel = 'high';
    } else if (riskScore >= 40) {
      riskLevel = 'medium';
    }

    final analysisLines = <String>[];
    analysisLines.add('YOLO 偵測到 ${detections.length} 個物件:');
    if (detectedItems.isNotEmpty) {
      analysisLines.add('- ${detectedItems.join(', ')}');
    }

    final recommendations = <String>['建議人工確認偵測結果是否需要處理'];

    return {
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'analysis': analysisLines.join('\n'),
      'recommendations': recommendations,
      'detections': detections.map((d) => d.toJson()).toList(),
      'detection_count': detections.length,
    };
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    _instance = null;
  }
}
