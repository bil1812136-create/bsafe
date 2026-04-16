/// Pure domain entity — no Flutter / JSON dependencies.
/// Represents a single building safety defect report.
class Report {
  final int? id;
  final String title;
  final String description;
  final String category;
  final String severity;
  final String riskLevel;
  final int riskScore;
  final bool isUrgent;
  final String status;
  final String? imagePath;
  final String? imageBase64;
  final String? imageUrl;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? aiAnalysis;
  final String? companyNotes;
  final String? workerResponse;
  final String? workerResponseImage;
  final List<ConversationMessage> conversation;
  final bool hasUnreadCompany;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool synced;

  const Report({
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
    this.workerResponse,
    this.workerResponseImage,
    this.conversation = const [],
    this.hasUnreadCompany = false,
    required this.createdAt,
    this.updatedAt,
    this.synced = false,
  });

  Report copyWith({
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
    String? workerResponse,
    String? workerResponseImage,
    List<ConversationMessage>? conversation,
    bool? hasUnreadCompany,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return Report(
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
      workerResponse: workerResponse ?? this.workerResponse,
      workerResponseImage: workerResponseImage ?? this.workerResponseImage,
      conversation: conversation ?? this.conversation,
      hasUnreadCompany: hasUnreadCompany ?? this.hasUnreadCompany,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  /// Merged conversation including legacy fields for backwards-compat.
  List<ConversationMessage> get mergedConversation {
    if (conversation.isNotEmpty) {
      final sorted = List<ConversationMessage>.from(conversation)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return sorted;
    }
    final legacy = <ConversationMessage>[];
    if (companyNotes != null && companyNotes!.isNotEmpty) {
      legacy.add(ConversationMessage(
        sender: 'company',
        text: companyNotes!,
        timestamp: updatedAt ?? createdAt,
      ));
    }
    if (workerResponse != null && workerResponse!.isNotEmpty) {
      legacy.add(ConversationMessage(
        sender: 'worker',
        text: workerResponse!,
        image: workerResponseImage,
        timestamp: updatedAt ?? createdAt,
      ));
    }
    legacy.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return legacy;
  }
}

/// Domain entity for a single message in a report conversation.
class ConversationMessage {
  final String sender; // 'worker' | 'company'
  final String text;
  final String? image;
  final DateTime timestamp;

  ConversationMessage({
    required this.sender,
    required this.text,
    this.image,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
