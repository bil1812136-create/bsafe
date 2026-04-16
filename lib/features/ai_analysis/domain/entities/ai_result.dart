/// AI analysis result entity
class AiResult {
  final bool damageDetected;
  final String severity;
  final String riskLevel;
  final int riskScore;
  final bool isUrgent;
  final String analysis;
  final String aiMode; // 'online' | 'local_fallback'

  const AiResult({
    required this.damageDetected,
    required this.severity,
    required this.riskLevel,
    required this.riskScore,
    required this.isUrgent,
    required this.analysis,
    this.aiMode = 'online',
  });
}
