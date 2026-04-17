import 'package:bsafe_app/core/usecases/usecase.dart';
import 'package:bsafe_app/features/ai/analysis/domain/entities/ai_result.dart';
import 'package:bsafe_app/features/ai/analysis/domain/repositories/ai_repository.dart';

class AnalyzeImageParams {
  final String imageBase64;
  final String? additionalContext;
  const AnalyzeImageParams({required this.imageBase64, this.additionalContext});
}

class AnalyzeImage implements UseCase<AiResult, AnalyzeImageParams> {
  final AiRepository repository;
  const AnalyzeImage(this.repository);

  @override
  Future<AiResult> call(AnalyzeImageParams params) {
    return repository.analyzeImage(
      params.imageBase64,
      additionalContext: params.additionalContext,
    );
  }
}
