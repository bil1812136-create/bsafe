/// UWB定位系统数据模型
/// 基于安信可UWB TWR系统
library;

/// 基站数据模型
class UwbAnchor {
  final String id;
  final double x; // X坐标 (米)
  final double y; // Y坐标 (米)
  final double z; // Z坐标/高度 (米)
  final bool isActive;

  UwbAnchor({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    this.isActive = true,
  });

  factory UwbAnchor.fromJson(Map<String, dynamic> json) {
    return UwbAnchor(
      id: json['id'] ?? '',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      z: (json['z'] ?? 0.0).toDouble(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'z': z,
      'isActive': isActive,
    };
  }

  @override
  String toString() => 'Anchor($id: $x, $y, $z)';
}

/// 标签数据模型 (追踪目标)
class UwbTag {
  final String id;
  final double x; // X坐标 (米)
  final double y; // Y坐标 (米)
  final double z; // Z坐标 (米)
  final double r95; // 定位精度
  final Map<String, double> anchorDistances; // 到各基站的距离
  final DateTime timestamp;

  UwbTag({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    this.r95 = 0.0,
    this.anchorDistances = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory UwbTag.fromJson(Map<String, dynamic> json) {
    final Map<String, double> distances = {};
    if (json['distances'] != null) {
      (json['distances'] as Map<String, dynamic>).forEach((key, value) {
        distances[key] = (value ?? 0.0).toDouble();
      });
    }

    return UwbTag(
      id: json['id'] ?? '',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      z: (json['z'] ?? 0.0).toDouble(),
      r95: (json['r95'] ?? 0.0).toDouble(),
      anchorDistances: distances,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'z': z,
      'r95': r95,
      'distances': anchorDistances,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() => 'Tag($id: $x, $y, $z)';
}

/// UWB系统配置
class UwbConfig {
  final String positioningMode; // 二维定位 / 三维定位
  final String algorithm; // 卡尔曼/平均算法
  final double areaRadius1; // 区域1半径 (米)
  final double areaRadius2; // 区域2半径 (米)
  final bool showTrajectory; // 显示轨迹
  final bool showHistoryTrajectory; // 显示历史轨迹
  final bool showFence; // 显示围栏
  final bool innerFenceAlarm; // 内围报警 (true) / 外围报警 (false)
  final double correctionA; // 距离校正系数a
  final double correctionB; // 距离校正系数b
  final double gridWidth; // 网格宽度 (米)
  final double gridHeight; // 网格高度 (米)
  final bool showGrid; // 显示网格
  final bool showAnchorList; // 显示基站列表
  final bool showTagList; // 显示标签列表
  final bool autoGetAnchorCoords; // 自动获取基站坐标
  final double xOffset; // X偏移 (像素)
  final double yOffset; // Y偏移 (像素)
  final double xScale; // X比例 (像素/米)
  final double yScale; // Y比例 (像素/米)
  final bool flipX; // 翻转X
  final bool flipY; // 翻转Y
  final bool showOrigin; // 显示原点
  final String? floorPlanImagePath; // 平面地圖圖片路徑
  final bool showFloorPlan; // 是否顯示平面地圖
  final double floorPlanOpacity; // 平面地圖透明度
  final String floorPlanFileType; // 平面地圖檔案類型 (image/svg/pdf/dwg)

  UwbConfig({
    this.positioningMode = '二維定位',
    this.algorithm = '卡爾曼/平均算法',
    this.areaRadius1 = 2.0,
    this.areaRadius2 = 4.0,
    this.showTrajectory = true,
    this.showHistoryTrajectory = false,
    this.showFence = false,
    this.innerFenceAlarm = true,
    this.correctionA = 0.78,
    this.correctionB = 0.0,
    this.gridWidth = 0.5,
    this.gridHeight = 0.5,
    this.showGrid = true,
    this.showAnchorList = true,
    this.showTagList = true,
    this.autoGetAnchorCoords = false,
    this.xOffset = 0.0,
    this.yOffset = 0.0,
    this.xScale = 50.0,
    this.yScale = 50.0,
    this.flipX = false,
    this.flipY = false,
    this.showOrigin = true,
    this.floorPlanImagePath,
    this.showFloorPlan = false,
    this.floorPlanOpacity = 0.5,
    this.floorPlanFileType = 'image',
  });

  UwbConfig copyWith({
    String? positioningMode,
    String? algorithm,
    double? areaRadius1,
    double? areaRadius2,
    bool? showTrajectory,
    bool? showHistoryTrajectory,
    bool? showFence,
    bool? innerFenceAlarm,
    double? correctionA,
    double? correctionB,
    double? gridWidth,
    double? gridHeight,
    bool? showGrid,
    bool? showAnchorList,
    bool? showTagList,
    bool? autoGetAnchorCoords,
    double? xOffset,
    double? yOffset,
    double? xScale,
    double? yScale,
    bool? flipX,
    bool? flipY,
    bool? showOrigin,
    String? floorPlanImagePath,
    bool? showFloorPlan,
    double? floorPlanOpacity,
    String? floorPlanFileType,
  }) {
    return UwbConfig(
      positioningMode: positioningMode ?? this.positioningMode,
      algorithm: algorithm ?? this.algorithm,
      areaRadius1: areaRadius1 ?? this.areaRadius1,
      areaRadius2: areaRadius2 ?? this.areaRadius2,
      showTrajectory: showTrajectory ?? this.showTrajectory,
      showHistoryTrajectory:
          showHistoryTrajectory ?? this.showHistoryTrajectory,
      showFence: showFence ?? this.showFence,
      innerFenceAlarm: innerFenceAlarm ?? this.innerFenceAlarm,
      correctionA: correctionA ?? this.correctionA,
      correctionB: correctionB ?? this.correctionB,
      gridWidth: gridWidth ?? this.gridWidth,
      gridHeight: gridHeight ?? this.gridHeight,
      showGrid: showGrid ?? this.showGrid,
      showAnchorList: showAnchorList ?? this.showAnchorList,
      showTagList: showTagList ?? this.showTagList,
      autoGetAnchorCoords: autoGetAnchorCoords ?? this.autoGetAnchorCoords,
      xOffset: xOffset ?? this.xOffset,
      yOffset: yOffset ?? this.yOffset,
      xScale: xScale ?? this.xScale,
      yScale: yScale ?? this.yScale,
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      showOrigin: showOrigin ?? this.showOrigin,
      floorPlanImagePath: floorPlanImagePath ?? this.floorPlanImagePath,
      showFloorPlan: showFloorPlan ?? this.showFloorPlan,
      floorPlanOpacity: floorPlanOpacity ?? this.floorPlanOpacity,
      floorPlanFileType: floorPlanFileType ?? this.floorPlanFileType,
    );
  }
}

/// 轨迹点
class TrajectoryPoint {
  final double x;
  final double y;
  final DateTime timestamp;

  TrajectoryPoint({
    required this.x,
    required this.y,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
