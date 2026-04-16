import 'package:bsafe_app/features/ai_analysis/domain/entities/ai_result.dart';

abstract class AiRepository {

  Future<AiResult> analyzeImage(String imageBase64,
      {String? additionalContext});
}
