import 'package:bsafe_app/features/defect_reporting/data/datasources/report_remote_datasource.dart';
import 'package:bsafe_app/features/defect_reporting/domain/entities/report.dart';
import 'package:bsafe_app/features/defect_reporting/domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportRemoteDataSource _remote;

  const ReportRepositoryImpl(this._remote);

  @override
  Future<List<Report>> fetchAll() async {
    final raw = await _remote.fetchAll();
    return raw.map(ReportRemoteDataSource.mapToModel).toList();
  }

  @override
  Future<Report?> create(Report report, {String? imageBase64}) =>
      _remote.create(report, imageBase64: imageBase64);

  @override
  Future<bool> updateStatus(int id, String newStatus) =>
      _remote.updateStatus(id, newStatus);

  @override
  Future<bool> submitWorkerResponse(
          int reportId, String text, String? imageBase64) =>
      _remote.submitWorkerResponse(reportId, text, imageBase64);

  @override
  Future<bool> addCompanyMessage(int reportId, String message) =>
      _remote.addCompanyMessage(reportId, message);

  @override
  Future<void> clearUnreadCompany(int reportId) =>
      _remote.clearUnreadCompany(reportId);

  @override
  Future<int> syncBatch(List<Report> reports) async {
    int count = 0;
    for (final r in reports) {
      if (await create(r) != null) count++;
    }
    return count;
  }
}
