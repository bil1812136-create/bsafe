import 'package:bsafe_app/core/usecases/usecase.dart';
import 'package:bsafe_app/features/defect_reporting/domain/repositories/report_repository.dart';

class UpdateReportStatusParams {
  final int id;
  final String newStatus;
  const UpdateReportStatusParams({required this.id, required this.newStatus});
}

class UpdateReportStatus implements UseCase<bool, UpdateReportStatusParams> {
  final ReportRepository repository;
  const UpdateReportStatus(this.repository);

  @override
  Future<bool> call(UpdateReportStatusParams params) =>
      repository.updateStatus(params.id, params.newStatus);
}
