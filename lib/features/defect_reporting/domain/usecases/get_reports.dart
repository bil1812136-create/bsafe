import 'package:bsafe_app/core/usecases/usecase.dart';
import 'package:bsafe_app/features/defect_reporting/domain/entities/report.dart';
import 'package:bsafe_app/features/defect_reporting/domain/repositories/report_repository.dart';

class GetReports implements UseCase<List<Report>, NoParams> {
  final ReportRepository repository;
  const GetReports(this.repository);

  @override
  Future<List<Report>> call(NoParams params) => repository.fetchAll();
}
