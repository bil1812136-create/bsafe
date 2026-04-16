import 'package:bsafe_app/features/ai_analysis/domain/entities/ai_result.dart';

abstract class AiRepository {
  /// Analyze an image (base64 encoded) and return AI result.
  Future<AiResult> analyzeImage(String imageBase64,
      {String? additionalContext});
}
