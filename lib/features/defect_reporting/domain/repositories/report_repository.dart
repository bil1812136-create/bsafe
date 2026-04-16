import 'package:bsafe_app/features/defect_reporting/domain/entities/report.dart';

abstract class ReportRepository {

  Future<List<Report>> fetchAll();

  Future<Report?> create(Report report, {String? imageBase64});

  Future<bool> updateStatus(int id, String newStatus);

  Future<bool> submitWorkerResponse(
      int reportId, String text, String? imageBase64);

  Future<bool> addCompanyMessage(int reportId, String message);

  Future<void> clearUnreadCompany(int reportId);

  Future<int> syncBatch(List<Report> reports);
}
