import 'package:flutter_test/flutter_test.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/features/report/data/datasources/report_remote_data_source.dart';
import 'package:kitatemani/features/report/data/repositories/report_repository_impl.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/domain/usecases/submit_report.dart';

void main() {
  group('SubmitReport UseCase', () {
    test('saves generated report code into ReportCodeStore on success',
        () async {
      final storage = InMemorySecureStorageService();
      final codeStore = SecureReportCodeStore(storage);
      final repo = ReportRepositoryImpl(const ReportRemoteDataSource());
      final useCase = SubmitReport(repo, codeStore);

      final draft = NewReport(
        idempotencyKey: 'uuid-test-1',
        schoolId: 'school-1',
        types: const {BullyingType.fisik},
        occurredAt: DateTime(2026, 11, 9, 10),
        whenLabel: 'Hari ini – 10:05 WIB',
        location: 'Koridor Lantai 2',
        narrative: 'Laporan uji coba kronologi perundungan di koridor sekolah.',
      );

      final result = await useCase(draft);
      expect(result.isOk, isTrue);
      final savedCode = (result as Ok<String>).value;
      expect(savedCode, startsWith('KT-'));

      final storedCodes = await codeStore.readCodes();
      expect(storedCodes, contains(savedCode));
    });
  });
}
