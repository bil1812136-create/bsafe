import 'dart:convert';
import 'package:bsafe_app/features/defect_reporting/domain/entities/report.dart';

class ReportModel extends Report {
  const ReportModel({
    super.id,
    required super.title,
    required super.description,
    required super.category,
    required super.severity,
    super.riskLevel = 'low',
    super.riskScore = 0,
    super.isUrgent = false,
    super.status = 'pending',
    super.imagePath,
    super.imageBase64,
    super.imageUrl,
    super.location,
    super.latitude,
    super.longitude,
    super.aiAnalysis,
    super.companyNotes,
    super.workerResponse,
    super.workerResponseImage,
    super.conversation = const [],
    super.hasUnreadCompany = false,
    required super.createdAt,
    super.updatedAt,
    super.synced = false,
  });

  Map<String, dynamic> toJson() => {
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
        'worker_response': workerResponse,
        'worker_response_image': workerResponseImage,
        'conversation': _conversationToJson(conversation),
        'has_unread_company': hasUnreadCompany,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory ReportModel.fromJson(Map<String, dynamic> json) => ReportModel(
        id: json['id'] as int?,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'other',
        severity: json['severity'] as String? ?? 'mild',
        riskLevel: json['risk_level'] as String? ?? 'low',
        riskScore: json['risk_score'] as int? ?? 0,
        isUrgent: json['is_urgent'] == true,
        status: json['status'] as String? ?? 'pending',
        imageBase64: json['image_base64'] as String?,
        imageUrl: json['image_url'] as String?,
        location: json['location'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        aiAnalysis: json['ai_analysis'] as String?,
        companyNotes: json['company_notes'] as String?,
        workerResponse: json['worker_response'] as String?,
        workerResponseImage: json['worker_response_image'] as String?,
        conversation: _conversationFromJson(json['conversation']),
        hasUnreadCompany: json['has_unread_company'] == true,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
        synced: true,
      );

  static String? _conversationToJson(List<ConversationMessage> list) {
    if (list.isEmpty) return null;
    return jsonEncode(list
        .map((m) => {
              'sender': m.sender,
              'text': m.text,
              'image': m.image,
              'timestamp': m.timestamp.toIso8601String(),
            })
        .toList());
  }

  static List<ConversationMessage> conversationFromJson(dynamic raw) =>
      _conversationFromJson(raw);

  static List<ConversationMessage> _conversationFromJson(dynamic raw) {
    if (raw == null) return [];
    try {
      final List<dynamic> list;
      if (raw is String) {
        if (raw.isEmpty) return [];
        final decoded = jsonDecode(raw);
        list = decoded is List ? decoded : [];
      } else if (raw is List) {
        list = raw;
      } else {
        return [];
      }
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return ConversationMessage(
          sender: m['sender'] as String? ?? 'worker',
          text: m['text'] as String? ?? '',
          image: m['image'] as String?,
          timestamp: m['timestamp'] != null
              ? DateTime.tryParse(m['timestamp'] as String) ?? DateTime.now()
              : DateTime.now(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Report toEntity() => this;

  factory ReportModel.fromEntity(Report r) => ReportModel(
        id: r.id,
        title: r.title,
        description: r.description,
        category: r.category,
        severity: r.severity,
        riskLevel: r.riskLevel,
        riskScore: r.riskScore,
        isUrgent: r.isUrgent,
        status: r.status,
        imagePath: r.imagePath,
        imageBase64: r.imageBase64,
        imageUrl: r.imageUrl,
        location: r.location,
        latitude: r.latitude,
        longitude: r.longitude,
        aiAnalysis: r.aiAnalysis,
        companyNotes: r.companyNotes,
        workerResponse: r.workerResponse,
        workerResponseImage: r.workerResponseImage,
        conversation: r.conversation,
        hasUnreadCompany: r.hasUnreadCompany,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        synced: r.synced,
      );

  static String getCategoryLabel(String category) {
    const map = {
      'structural': '結構性問題',
      'exterior': '外牆問題',
      'public_area': '公共區域',
      'electrical': '電氣問題',
      'plumbing': '水管問題',
      'other': '其他',
    };
    return map[category] ?? category;
  }

  static String getSeverityLabel(String severity) {
    const map = {'mild': '輕微', 'moderate': '中度', 'severe': '嚴重'};
    return map[severity] ?? severity;
  }

  static List<Map<String, String>> get categories => [
        {'value': 'structural', 'label': '結構性問題', 'icon': '🏗️'},
        {'value': 'exterior', 'label': '外牆問題', 'icon': '🧱'},
        {'value': 'public_area', 'label': '公共區域', 'icon': '🚪'},
        {'value': 'electrical', 'label': '電氣問題', 'icon': '⚡'},
        {'value': 'plumbing', 'label': '水管問題', 'icon': '🚰'},
        {'value': 'other', 'label': '其他', 'icon': '📋'},
      ];

  static List<Map<String, String>> get severities => [
        {'value': 'mild', 'label': '輕微'},
        {'value': 'moderate', 'label': '中度'},
        {'value': 'severe', 'label': '嚴重'},
      ];
}
