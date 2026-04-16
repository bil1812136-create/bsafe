import 'package:bsafe_app/features/defect_reporting/domain/entities/report.dart';

/// Abstract contract for all report persistence operations.
/// Implemented in the data layer; depends only on domain types.
abstract class ReportRepository {
  /// Fetches all reports from the remote source (Supabase).
  Future<List<Report>> fetchAll();

  /// Creates a new report and returns the persisted instance.
  Future<Report?> create(Report report, {String? imageBase64});

  /// Updates the status of an existing report.
  Future<bool> updateStatus(int id, String newStatus);

  /// Appends a worker response (text + optional image) to a report.
  Future<bool> submitWorkerResponse(
      int reportId, String text, String? imageBase64);

  /// Appends a company message to a report.
  Future<bool> addCompanyMessage(int reportId, String message);

  /// Clears the unread-company flag on a report.
  Future<void> clearUnreadCompany(int reportId);

  /// Syncs multiple reports to the remote source. Returns synced count.
  Future<int> syncBatch(List<Report> reports);
}
