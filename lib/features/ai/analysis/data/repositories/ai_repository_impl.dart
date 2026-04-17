import 'package:bsafe_app/features/ai/analysis/data/datasources/ai_remote_datasource.dart';
import 'package:bsafe_app/features/ai/analysis/domain/entities/ai_result.dart';
import 'package:bsafe_app/features/ai/analysis/domain/repositories/ai_repository.dart';

class AiRepositoryImpl implements AiRepository {
  final AiRemoteDataSource remoteDataSource;
  const AiRepositoryImpl(this.remoteDataSource);

  @override
  Future<AiResult> analyzeImage(String imageBase64,
      {String? additionalContext}) async {
    final raw = await remoteDataSource.analyzeImage(
      imageBase64,
      additionalContext: additionalContext,
    );
    return AiResult(
      damageDetected: raw['damage_detected'] as bool? ?? true,
      severity: raw['severity'] as String? ?? 'moderate',
      riskLevel: raw['risk_level'] as String? ?? 'medium',
      riskScore: (raw['risk_score'] as num?)?.toInt() ?? 55,
      isUrgent: raw['is_urgent'] as bool? ?? false,
      analysis: raw['analysis'] as String? ?? '',
      aiMode: raw['_ai_mode'] as String? ?? 'online',
    );
  }
}
