class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );
}

class Defect {
  final String id;
  final String? imagePath;
  final String? imageBase64;
  final Map<String, dynamic>? aiResult;
  final String? category;
  final String? severity;
  final int riskScore;
  final String riskLevel;
  final String? description;
  final List<String> recommendations;
  final String status;
  final List<ChatMessage> chatMessages;
  final DateTime createdAt;

  Defect({
    required this.id,
    this.imagePath,
    this.imageBase64,
    this.aiResult,
    this.category,
    this.severity,
    this.riskScore = 0,
    this.riskLevel = 'low',
    this.description,
    this.recommendations = const [],
    this.status = 'pending',
    this.chatMessages = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Defect copyWith({
    String? id,
    String? imagePath,
    String? imageBase64,
    Map<String, dynamic>? aiResult,
    String? category,
    String? severity,
    int? riskScore,
    String? riskLevel,
    String? description,
    List<String>? recommendations,
    String? status,
    List<ChatMessage>? chatMessages,
    DateTime? createdAt,
  }) {
    return Defect(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      aiResult: aiResult ?? this.aiResult,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      description: description ?? this.description,
      recommendations: recommendations ?? this.recommendations,
      status: status ?? this.status,
      chatMessages: chatMessages ?? this.chatMessages,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'imageBase64': imageBase64,
        'aiResult': aiResult,
        'category': category,
        'severity': severity,
        'riskScore': riskScore,
        'riskLevel': riskLevel,
        'description': description,
        'recommendations': recommendations,
        'status': status,
        'chatMessages': chatMessages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Defect.fromJson(Map<String, dynamic> json) => Defect(
        id: json['id'] as String? ?? '',
        imagePath: json['imagePath'] as String?,
        imageBase64: json['imageBase64'] as String?,
        aiResult: json['aiResult'] as Map<String, dynamic>?,
        category: json['category'] as String?,
        severity: json['severity'] as String?,
        riskScore: json['riskScore'] as int? ?? 0,
        riskLevel: json['riskLevel'] as String? ?? 'low',
        description: json['description'] as String?,
        recommendations: (json['recommendations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        status: json['status'] as String? ?? 'pending',
        chatMessages: (json['chatMessages'] as List<dynamic>?)
                ?.map(
                    (e) => ChatMessage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  bool get isAnalyzed => status == 'analyzed' || status == 'reviewed';

  String get riskLevelLabel {
    switch (riskLevel) {
      case 'high':
        return '高風險';
      case 'medium':
        return '中風險';
      case 'low':
        return '低風險';
      default:
        return '未評估';
    }
  }
}

class InspectionPin {
  final String id;
  final double x;
  final double y;
  final List<Defect> defects;

  final String? imagePath;
  final String? imageBase64;
  final Map<String, dynamic>? aiResult;
  final String? category;
  final String? severity;
  final int riskScore;
  final String riskLevel;
  final String? description;
  final List<String> recommendations;
  final String status;
  final DateTime createdAt;
  final String? note;

  InspectionPin({
    required this.id,
    required this.x,
    required this.y,
    this.defects = const [],
    this.imagePath,
    this.imageBase64,
    this.aiResult,
    this.category,
    this.severity,
    this.riskScore = 0,
    this.riskLevel = 'low',
    this.description,
    this.recommendations = const [],
    this.status = 'pending',
    DateTime? createdAt,
    this.note,
  }) : createdAt = createdAt ?? DateTime.now();

  InspectionPin copyWith({
    String? id,
    double? x,
    double? y,
    List<Defect>? defects,
    String? imagePath,
    String? imageBase64,
    Map<String, dynamic>? aiResult,
    String? category,
    String? severity,
    int? riskScore,
    String? riskLevel,
    String? description,
    List<String>? recommendations,
    String? status,
    DateTime? createdAt,
    String? note,
  }) {
    return InspectionPin(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      defects: defects ?? this.defects,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      aiResult: aiResult ?? this.aiResult,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      description: description ?? this.description,
      recommendations: recommendations ?? this.recommendations,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'defects': defects.map((d) => d.toJson()).toList(),
      'imagePath': imagePath,
      'imageBase64': imageBase64,
      'aiResult': aiResult,
      'category': category,
      'severity': severity,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'description': description,
      'recommendations': recommendations,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
    };
  }

  factory InspectionPin.fromJson(Map<String, dynamic> json) {
    return InspectionPin(
      id: json['id'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      defects: (json['defects'] as List<dynamic>?)
              ?.map((e) => Defect.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      imagePath: json['imagePath'] as String?,
      imageBase64: json['imageBase64'] as String?,
      aiResult: json['aiResult'] as Map<String, dynamic>?,
      category: json['category'] as String?,
      severity: json['severity'] as String?,
      riskScore: json['riskScore'] as int? ?? 0,
      riskLevel: json['riskLevel'] as String? ?? 'low',
      description: json['description'] as String?,
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      note: json['note'] as String?,
    );
  }

  String get riskLevelLabel {
    switch (riskLevel) {
      case 'high':
        return '高風險';
      case 'medium':
        return '中風險';
      case 'low':
        return '低風險';
      default:
        return '未評估';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return '待拍照';
      case 'analyzed':
        return '已分析';
      case 'reviewed':
        return '已審查';
      default:
        return status;
    }
  }

  bool get isAnalyzed => status == 'analyzed' || status == 'reviewed';

  int get maxDefectRiskScore {
    if (defects.isEmpty) return riskScore;
    final scores = defects.map((d) => d.riskScore).toList();
    if (riskScore > 0) scores.add(riskScore);
    return scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
  }

  String get maxDefectRiskLevel {
    if (defects.isEmpty) return riskLevel;
    const order = {'high': 3, 'medium': 2, 'low': 1};
    String maxLevel = riskLevel;
    int maxOrder = order[riskLevel] ?? 0;
    for (final d in defects) {
      final o = order[d.riskLevel] ?? 0;
      if (o > maxOrder) {
        maxOrder = o;
        maxLevel = d.riskLevel;
      }
    }
    return maxLevel;
  }

  int get defectCount => defects.length;

  bool get hasAnalyzedDefects => defects.any((d) => d.isAnalyzed);
}

class InspectionSession {
  final String id;
  final String name;
  final String? projectId;
  final int floor;
  final String? floorPlanPath;
  final List<InspectionPin> pins;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status;

  InspectionSession({
    required this.id,
    required this.name,
    this.projectId,
    this.floor = 1,
    this.floorPlanPath,
    this.pins = const [],
    DateTime? createdAt,
    this.updatedAt,
    this.status = 'active',
  }) : createdAt = createdAt ?? DateTime.now();

  InspectionSession copyWith({
    String? id,
    String? name,
    String? projectId,
    int? floor,
    String? floorPlanPath,
    List<InspectionPin>? pins,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return InspectionSession(
      id: id ?? this.id,
      name: name ?? this.name,
      projectId: projectId ?? this.projectId,
      floor: floor ?? this.floor,
      floorPlanPath: floorPlanPath ?? this.floorPlanPath,
      pins: pins ?? this.pins,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'projectId': projectId,
      'floor': floor,
      'floorPlanPath': floorPlanPath,
      'pins': pins.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'status': status,
    };
  }

  factory InspectionSession.fromJson(Map<String, dynamic> json) {
    return InspectionSession(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名',
      projectId: json['projectId'] as String?,
      floor: json['floor'] as int? ?? 1,
      floorPlanPath: json['floorPlanPath'] as String?,
      pins: (json['pins'] as List<dynamic>?)
              ?.map((e) => InspectionPin.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      status: json['status'] as String? ?? 'active',
    );
  }

  int get totalPins => pins.length;

  int get analyzedPins => pins.where((p) => p.isAnalyzed).length;

  int get highRiskPins =>
      pins.where((p) => p.riskLevel == 'high').length;

  List<Defect> get allDefects =>
      pins.expand((p) => p.defects).toList();

  int get lowRiskDefects =>
      allDefects.where((d) => d.riskLevel == 'low').length;

  int get mediumRiskDefects =>
      allDefects.where((d) => d.riskLevel == 'medium').length;

  int get highRiskDefects =>
      allDefects.where((d) => d.riskLevel == 'high').length;

  double get averageRiskScore {
    if (pins.isEmpty) return 0;
    final analyzed = pins.where((p) => p.isAnalyzed).toList();
    if (analyzed.isEmpty) return 0;
    return analyzed.map((p) => p.riskScore).reduce((a, b) => a + b) /
        analyzed.length;
  }
}
