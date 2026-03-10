class ReportModel {
  final int? id;
  final String title;
  final String description;
  final String
      category; // structural, exterior, public_area, electrical, plumbing, other
  final String severity; // mild, moderate, severe
  final String riskLevel; // low, medium, high
  final int riskScore; // 0-100
  final bool isUrgent;
  final String status; // pending, in_progress, resolved
  final String? imagePath;
  final String? imageBase64;
  final String? imageUrl; // Supabase Storage 雲端圖片 URL
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? aiAnalysis;
  final String? companyNotes; // 公司後台回饋 / 跟進任務
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool synced;

  ReportModel({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    this.riskLevel = 'low',
    this.riskScore = 0,
    this.isUrgent = false,
    this.status = 'pending',
    this.imagePath,
    this.imageBase64,
    this.imageUrl,
    this.location,
    this.latitude,
    this.longitude,
    this.aiAnalysis,
    this.companyNotes,
    DateTime? createdAt,
    this.updatedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'severity': severity,
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'is_urgent': isUrgent ? 1 : 0,
      'status': status,
      'image_path': imagePath,
      'image_base64': imageBase64,
      'image_url': imageUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'ai_analysis': aiAnalysis,
      'company_notes': companyNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  // Create from database Map
  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      severity: map['severity'] as String,
      riskLevel: map['risk_level'] as String? ?? 'low',
      riskScore: map['risk_score'] as int? ?? 0,
      isUrgent: (map['is_urgent'] as int?) == 1,
      status: map['status'] as String? ?? 'pending',
      imagePath: map['image_path'] as String?,
      imageBase64: map['image_base64'] as String?,
      imageUrl: map['image_url'] as String?,
      location: map['location'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      aiAnalysis: map['ai_analysis'] as String?,
      companyNotes: map['company_notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      synced: (map['synced'] as int?) == 1,
    );
  }

  // Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'severity': severity,
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'is_urgent': isUrgent,
      'status': status,
      'image_base64': imageBase64,
      'image_url': imageUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'ai_analysis': aiAnalysis,
      'company_notes': companyNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Create from API JSON
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      severity: json['severity'] as String,
      riskLevel: json['risk_level'] as String? ?? 'low',
      riskScore: json['risk_score'] as int? ?? 0,
      isUrgent: json['is_urgent'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      imageBase64: json['image_base64'] as String?,
      imageUrl: json['image_url'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      aiAnalysis: json['ai_analysis'] as String?,
      companyNotes: json['company_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      synced: true,
    );
  }

  // Copy with modifications
  ReportModel copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    String? severity,
    String? riskLevel,
    int? riskScore,
    bool? isUrgent,
    String? status,
    String? imagePath,
    String? imageBase64,
    String? imageUrl,
    String? location,
    double? latitude,
    double? longitude,
    String? aiAnalysis,
    String? companyNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return ReportModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      riskLevel: riskLevel ?? this.riskLevel,
      riskScore: riskScore ?? this.riskScore,
      isUrgent: isUrgent ?? this.isUrgent,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      companyNotes: companyNotes ?? this.companyNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  // Category labels in Chinese
  static String getCategoryLabel(String category) {
    switch (category) {
      case 'structural':
        return '結構性問題';
      case 'exterior':
        return '外牆問題';
      case 'public_area':
        return '公共區域';
      case 'electrical':
        return '電氣問題';
      case 'plumbing':
        return '水管問題';
      case 'other':
        return '其他';
      default:
        return category;
    }
  }

  // Severity labels in Chinese
  static String getSeverityLabel(String severity) {
    switch (severity) {
      case 'mild':
        return '輕微';
      case 'moderate':
        return '中度';
      case 'severe':
        return '嚴重';
      default:
        return severity;
    }
  }

  // All categories
  static List<Map<String, String>> get categories => [
        {'value': 'structural', 'label': '結構性問題', 'icon': '🏗️'},
        {'value': 'exterior', 'label': '外牆問題', 'icon': '🧱'},
        {'value': 'public_area', 'label': '公共區域', 'icon': '🚪'},
        {'value': 'electrical', 'label': '電氣問題', 'icon': '⚡'},
        {'value': 'plumbing', 'label': '水管問題', 'icon': '🚰'},
        {'value': 'other', 'label': '其他', 'icon': '📋'},
      ];

  // All severities
  static List<Map<String, String>> get severities => [
        {'value': 'mild', 'label': '輕微'},
        {'value': 'moderate', 'label': '中度'},
        {'value': 'severe', 'label': '嚴重'},
      ];
}
