class AnalysisRecord {
  AnalysisRecord({
    required this.id,
    required this.imageName,
    required this.result,
    required this.createdAt,
    this.error,
  });

  final String id;
  final String imageName;
  final String result;
  final DateTime createdAt;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageName': imageName,
      'result': result,
      'createdAt': createdAt.toIso8601String(),
      'error': error,
    };
  }

  factory AnalysisRecord.fromJson(Map<String, dynamic> json) {
    return AnalysisRecord(
      id: json['id']?.toString() ?? '',
      imageName: json['imageName']?.toString() ?? 'unknown',
      result: json['result']?.toString() ?? 'Unknown',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      error: json['error']?.toString(),
    );
  }
}
