import 'dart:io';
import 'package:flutter/foundation.dart';

// Conditional import: ultralytics_yolo only works on Android/iOS
import 'package:ultralytics_yolo/yolo.dart';

/// YOLO 物件偵測結果
class YoloDetection {
  final String className;
  final double confidence;
  final double x; // center x (normalized 0-1 of image width)
  final double y; // center y (normalized 0-1 of image height)
  final double width; // box width (normalized)
  final double height; // box height (normalized)

  YoloDetection({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// 建構 bounding box 在實際圖片上的座標 (pixel values)
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

/// YOLO 偵測服務 - 包裝 ultralytics_yolo 套件
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

  /// 檢查平台是否支援 YOLO (目前僅 Android/iOS)
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  /// 初始化 YOLO 模型
  Future<bool> loadModel({String modelPath = 'yolo11n'}) async {
    if (!isSupported) {
      debugPrint('YOLO: 不支援此平台 (僅 Android/iOS)');
      return false;
    }

    if (_isLoaded) return true;
    if (_isLoading) return false;

    _isLoading = true;

    try {
      // Android 用 .tflite，iOS 用模型名稱
      final path = Platform.isAndroid ? '$modelPath.tflite' : modelPath;

      _yolo = YOLO(
        modelPath: path,
        task: YOLOTask.detect,
      );

      await _yolo!.loadModel();
      _isLoaded = true;
      debugPrint('YOLO: 模型載入成功');
      return true;
    } catch (e) {
      debugPrint('YOLO: 模型載入失敗: $e');
      _yolo = null;
      _isLoaded = false;
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// 對圖片執行物件偵測
  Future<List<YoloDetection>> detect(Uint8List imageBytes,
      {double confidenceThreshold = 0.25}) async {
    if (!_isLoaded || _yolo == null) {
      // 嘗試自動載入
      final loaded = await loadModel();
      if (!loaded) return [];
    }

    try {
      final results = await _yolo!.predict(
        imageBytes,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: 0.45,
      );

      final boxes = results['boxes'] as List<dynamic>? ?? [];
      final detections = <YoloDetection>[];

      for (final box in boxes) {
        final map = box as Map<dynamic, dynamic>;
        detections.add(YoloDetection(
          className: (map['class'] as String?) ?? 'unknown',
          confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
          x: (map['x'] as num?)?.toDouble() ?? 0.0,
          y: (map['y'] as num?)?.toDouble() ?? 0.0,
          width: (map['width'] as num?)?.toDouble() ?? 0.0,
          height: (map['height'] as num?)?.toDouble() ?? 0.0,
        ));
      }

      debugPrint('YOLO: 偵測到 ${detections.length} 個物件');
      return detections;
    } catch (e) {
      debugPrint('YOLO: 偵測失敗: $e');
      return [];
    }
  }

  /// 將偵測結果轉換為建築安全風險分析
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

    // 分類偵測物件為安全相關類別
    final safetyHazards = <String>[];
    final structuralItems = <String>[];
    final normalItems = <String>[];

    // COCO dataset 中與建築安全相關的類別
    const hazardClasses = {
      'fire hydrant', 'stop sign', 'traffic light', // 消防/安全設備
      'scissors', 'knife', // 尖銳物品
    };
    const structuralClasses = {
      'chair', 'couch', 'bed', 'dining table', 'toilet', 'sink', // 家具
      'tv', 'laptop', 'microwave', 'oven', 'refrigerator', // 電器
      'door', 'window', // 建築結構
    };
    const personClasses = {'person'};

    int personCount = 0;

    for (final det in detections) {
      final cls = det.className.toLowerCase();
      if (personClasses.contains(cls)) {
        personCount++;
      } else if (hazardClasses.contains(cls)) {
        safetyHazards.add('${det.className} (${(det.confidence * 100).toStringAsFixed(0)}%)');
      } else if (structuralClasses.contains(cls)) {
        structuralItems.add('${det.className} (${(det.confidence * 100).toStringAsFixed(0)}%)');
      } else {
        normalItems.add('${det.className} (${(det.confidence * 100).toStringAsFixed(0)}%)');
      }
    }

    // 計算風險分數
    int riskScore = 10; // 基礎分
    String riskLevel = 'low';

    if (safetyHazards.isNotEmpty) {
      riskScore += safetyHazards.length * 20;
    }
    if (personCount > 3) {
      riskScore += 15; // 人員密集
    }
    riskScore = riskScore.clamp(0, 100);

    if (riskScore >= 70) {
      riskLevel = 'high';
    } else if (riskScore >= 40) {
      riskLevel = 'medium';
    }

    // 組合分析說明
    final analysisLines = <String>[];
    analysisLines.add('YOLO 偵測到 ${detections.length} 個物件:');
    if (personCount > 0) {
      analysisLines.add('- 人員: $personCount 人');
    }
    if (safetyHazards.isNotEmpty) {
      analysisLines.add('- 安全相關: ${safetyHazards.join(', ')}');
    }
    if (structuralItems.isNotEmpty) {
      analysisLines.add('- 設施/家具: ${structuralItems.join(', ')}');
    }
    if (normalItems.isNotEmpty) {
      analysisLines.add('- 其他物件: ${normalItems.join(', ')}');
    }

    // 建議
    final recommendations = <String>[];
    if (safetyHazards.isNotEmpty) {
      recommendations.add('偵測到安全相關物件，請確認消防設備狀態');
    }
    if (personCount > 3) {
      recommendations.add('人員密集，請注意疏散通道暢通');
    }
    if (structuralItems.isNotEmpty) {
      recommendations.add('請檢查設施狀態是否正常');
    }
    if (recommendations.isEmpty) {
      recommendations.add('環境正常，定期巡檢即可');
    }

    return {
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'analysis': analysisLines.join('\n'),
      'recommendations': recommendations,
      'detections': detections.map((d) => d.toJson()).toList(),
      'detection_count': detections.length,
      'person_count': personCount,
    };
  }

  /// 釋放模型資源
  Future<void> dispose() async {
    try {
      await _yolo?.dispose();
    } catch (e) {
      debugPrint('YOLO dispose error: $e');
    }
    _yolo = null;
    _isLoaded = false;
    _instance = null;
  }
}
