import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/domain/repositories/report_repository.dart';

class SubmitReport {
  const SubmitReport(this._repository, this._codes);

  final ReportRepository _repository;
  final ReportCodeStore _codes;

  Future<Result<String>> call(NewReport draft) async {
    final result = await _repository.submit(draft);
    if (result case Ok(:final value)) {
      await _codes.save(value);
    }
    return result;
  }
}
