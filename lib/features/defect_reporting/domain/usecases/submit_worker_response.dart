import 'package:bsafe_app/core/usecases/usecase.dart';
import 'package:bsafe_app/features/defect_reporting/domain/repositories/report_repository.dart';

class SubmitWorkerResponseParams {
  final int reportId;
  final String text;
  final String? imageBase64;
  const SubmitWorkerResponseParams({
    required this.reportId,
    required this.text,
    this.imageBase64,
  });
}

class SubmitWorkerResponse
    implements UseCase<bool, SubmitWorkerResponseParams> {
  final ReportRepository repository;
  const SubmitWorkerResponse(this.repository);

  @override
  Future<bool> call(SubmitWorkerResponseParams params) => repository
      .submitWorkerResponse(params.reportId, params.text, params.imageBase64);
}
