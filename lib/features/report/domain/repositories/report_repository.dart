import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';

abstract interface class ReportCodeStore {
  Future<List<String>> readCodes();
  Future<void> save(String code);
}

abstract interface class ReportRepository {
  Future<Result<String>> submit(NewReport draft);
  Future<Result<ReportStatus>> statusOf(String code);
  Future<List<AnonymousReportItem>> getMyReports();
  Future<List<AnonymousReportItem>> getSchoolReports();
  Future<ReportDetailData> getReportDetail(String code);
  Future<Result<ReportChatMessage>> sendReportMessage({
    required String code,
    required String content,
    required String senderLabel,
    bool asCounselor = false,
  });
  Future<Result<List<AnonymousReportItem>>> advanceReportStatus(
    String code, {
    ReportStatus? nextStatus,
    String? note,
  });
  Future<int> syncOfflineQueue();
}
