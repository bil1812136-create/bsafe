/// 專案模型 - 一棟大廈的巡檢專案
class Project {
  final String id;
  final String buildingName; // 大廈名稱
  final int floorCount; // 樓層數目
  final int currentFloor; // 目前選中的樓層 (1-based)
  final DateTime createdAt;
  final DateTime? updatedAt;

  Project({
    required this.id,
    required this.buildingName,
    required this.floorCount,
    this.currentFloor = 1,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Project copyWith({
    String? id,
    String? buildingName,
    int? floorCount,
    int? currentFloor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      buildingName: buildingName ?? this.buildingName,
      floorCount: floorCount ?? this.floorCount,
      currentFloor: currentFloor ?? this.currentFloor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buildingName': buildingName,
      'floorCount': floorCount,
      'currentFloor': currentFloor,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? '',
      buildingName: json['buildingName'] as String? ?? '未命名',
      floorCount: json['floorCount'] as int? ?? 1,
      currentFloor: json['currentFloor'] as int? ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
