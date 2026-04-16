import 'package:bsafe_app/core/usecases/usecase.dart';
import 'package:bsafe_app/features/defect_reporting/domain/entities/report.dart';
import 'package:bsafe_app/features/defect_reporting/domain/repositories/report_repository.dart';

class CreateReportParams {
  final Report report;
  final String? imageBase64;
  const CreateReportParams({required this.report, this.imageBase64});
}

/// Use-case: persist a new defect report.
class CreateReport implements UseCase<Report?, CreateReportParams> {
  final ReportRepository repository;
  const CreateReport(this.repository);

  @override
  Future<Report?> call(CreateReportParams params) =>
      repository.create(params.report, imageBase64: params.imageBase64);
}
