import 'package:flutter/foundation.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// One detected instance from YOLO-seg.
class YoloDetection {
  final String className;
  final double confidence;

  // Bounding-box centre + size, all normalised to [0, 1].
  final double x;
  final double y;
  final double width;
  final double height;

  /// Instance mask, values 0–1.
  /// null when the model produced no segmentation masks.
  final List<List<double>>? mask;

  const YoloDetection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.mask,
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

/// Singleton service for YOLO inference via the ultralytics_yolo plugin.
///
/// Supports Android and iOS only (ultralytics_yolo is a platform plugin).
/// Use [isSupported] before calling [loadModel] or [detect].
class YoloService {
  static YoloService? _instance;

  YOLO? _yolo;
  bool _isLoaded = false;
  bool _isLoading = false;

  YoloService._();

  static YoloService get instance {
    _instance ??= YoloService._();
    return _instance!;
  }

  /// ultralytics_yolo is Android/iOS only — not available on web or desktop.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  // ───────────────────────────── model loading ─────────────────────────────

  Future<bool> loadModel(
      {String modelPath = 'flutter_assets/assets/model/yolo.tflite'}) async {
    if (!isSupported) return false;
    if (_isLoaded) return true;
    if (_isLoading) return false;
    _isLoading = true;
    try {
      _yolo = YOLO(
        modelPath: modelPath,
        task: YOLOTask.segment,
        useGpu: false,
      );
      final ok = await _yolo!.loadModel();
      _isLoaded = ok;
      debugPrint('YOLO: model ${ok ? 'loaded' : 'failed to load'}');
    } catch (e) {
      debugPrint('YOLO: load failed: $e');
      _yolo = null;
      _isLoaded = false;
    } finally {
      _isLoading = false;
    }
    return _isLoaded;
  }

  // ───────────────────────────── inference ─────────────────────────────────

  Future<List<YoloDetection>> detect(
    Uint8List imageBytes, {
    double confidenceThreshold = 0.25,
    double iouThreshold = 0.45,
  }) async {
    // Wait for any in-progress load to finish before checking _isLoaded.
    if (_isLoading) {
      // Poll until loading finishes (max 15 s).
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (_isLoading && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    if (!_isLoaded) {
      final ok = await loadModel();
      if (!ok) return [];
    }
    final yolo = _yolo;
    if (yolo == null) return [];

    try {
      final resultMap = await yolo.predict(
        imageBytes,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      );

      final rawList = resultMap['detections'] as List<dynamic>?;
      if (rawList == null || rawList.isEmpty) return [];

      final detections = <YoloDetection>[];
      for (final raw in rawList) {
        final result = YOLOResult.fromMap(raw as Map<dynamic, dynamic>);
        final box = result.normalizedBox; // Rect with left/top/right/bottom 0-1
        final bw = box.width;
        final bh = box.height;
        if (bw <= 0 || bh <= 0) continue;
        detections.add(YoloDetection(
          className: result.className,
          confidence: result.confidence,
          x: box.left + bw / 2,
          y: box.top + bh / 2,
          width: bw,
          height: bh,
          mask: result.mask,
        ));
      }
      debugPrint('YOLO: 偵測到 ${detections.length} 個物件');
      return detections;
    } catch (e, st) {
      debugPrint('YOLO: detect error: $e\n$st');
      return [];
    }
  }

  // ───────────────────────────── safety analysis ───────────────────────────

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

    int riskScore = 10 + (detections.length * 5).clamp(0, 60);
    riskScore = riskScore.clamp(0, 100);

    final riskLevel = riskScore >= 70
        ? 'high'
        : riskScore >= 40
            ? 'medium'
            : 'low';

    return {
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'analysis':
          'YOLO 偵測到 ${detections.length} 個物件:\n- ${detectedItems.join(', ')}',
      'recommendations': ['建議人工確認偵測結果是否需要處理'],
      'detections': detections.map((d) => d.toJson()).toList(),
      'detection_count': detections.length,
    };
  }

  Future<void> dispose() async {
    _yolo = null;
    _isLoaded = false;
    _instance = null;
  }
}
