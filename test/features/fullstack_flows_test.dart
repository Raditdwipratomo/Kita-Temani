import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/media_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/curhai/data/repositories/curhai_repository_impl.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_message.dart';
import 'package:kitatemani/features/emergency_contacts/data/repositories/emergency_contact_repository_impl.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';
import 'package:kitatemani/features/report/data/datasources/report_remote_data_source.dart';
import 'package:kitatemani/features/report/data/repositories/report_repository_impl.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';

void main() {
  group('MediaService EXIF stripping', () {
    test('re-encodes JPEG bytes cleanly without crashing', () {
      final image = img.Image(width: 16, height: 16);
      img.fill(image, color: img.ColorRgb8(88, 95, 230));
      final rawBytes = Uint8List.fromList(img.encodeJpg(image));

      final service = MediaService();
      final stripped = service.stripExifBytes(rawBytes);

      expect(stripped.isNotEmpty, isTrue);
      final decoded = img.decodeImage(stripped);
      expect(decoded, isNotNull);
      expect(decoded!.width, 16);
    });
  });

  group('CurhAI Repository', () {
    test(
        'detects crisis keywords and returns error without dummy reply when backend is offline',
        () async {
      expect(
        detectCrisisRiskLevel('Aku putus asa dan tidak kuat lagi.'),
        CrisisRiskLevel.crisis,
      );
      expect(
        detectCrisisRiskLevel('Aku diejek teman di kelas hari ini.'),
        CrisisRiskLevel.elevated,
      );

      final repo = FullstackCurhaiRepository(
        client: null,
        connectivity: DummyConnectivityService(),
      );

      final res = await repo.sendMessage(
        userText: 'Aku putus asa dan tidak kuat lagi.',
        history: const [],
      );

      expect(res, isA<Err<ChatMessage>>());

      final offTopicRes = await repo.sendMessage(
        userText: 'Apa rumus luas lingkaran?',
        history: const [],
      );

      expect(offTopicRes, isA<Ok<ChatMessage>>());
      if (offTopicRes case Ok(:final value)) {
        expect(value.isOutOfScope, isTrue);
        expect(value.showQuickActions, isFalse);
      }
    });
  });

  group('EmergencyContactRepository limits', () {
    test(
        'starts empty, enforces max 5 contacts per account, and keeps 1 primary',
        () async {
      final repo = DummyEmergencyContactRepository();
      expect(await repo.getAll(), isEmpty);

      for (var i = 1; i <= 5; i++) {
        final res = await repo.saveContact(
          EmergencyContact(
            id: '',
            name: 'Kontak $i',
            roleLabel: i == 5 ? 'Saudara' : 'Orang Tua',
            phone: '081111111$i',
            isActive: true,
            isPrimary: i == 5,
          ),
        );
        expect(res.isOk, isTrue);
      }

      final r6 = await repo.saveContact(
        const EmergencyContact(
          id: '',
          name: 'Kontak 6',
          roleLabel: 'Saudara',
          phone: '0833333333',
          isActive: true,
          isPrimary: false,
        ),
      );

      expect(r6.isErr, isTrue);

      final all = await repo.getAll();
      expect(all.length, 5);
      final primary = await repo.primaryContact();
      expect(primary?.name, 'Kontak 5');
      expect(primary?.isPrimary, isTrue);
      expect(
        RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(primary?.id ?? ''),
        isTrue,
      );
    });
  });

  group('ReportRepository two-way discussion and status flow', () {
    test('starts empty, submits report, advances status, and saves reply',
        () async {
      final repo = ReportRepositoryImpl(
        const ReportRemoteDataSource(),
        prefs: LocalPreferencesService(null),
      );
      expect(await repo.getMyReports(), isEmpty);

      final submitted = await repo.submit(
        NewReport(
          idempotencyKey: 'uuid-flow-test-1',
          schoolId: defaultSchoolSlug,
          types: const {BullyingType.verbal},
          occurredAt: DateTime(2026, 11, 21),
          whenLabel: '21 Nov 2026',
          location: 'Kelas',
          narrative: 'Pengujian pengiriman laporan bullying secara penuh.',
        ),
      );
      expect(submitted.isOk, isTrue);
      final code = (submitted as Ok<String>).value;

      final updatedRes = await repo.advanceReportStatus(code);
      expect(updatedRes.isOk, isTrue);
      final statusRes = await repo.statusOf(code);
      expect((statusRes as Ok<ReportStatus>).value, ReportStatus.ditinjau);

      final msgRes = await repo.sendReportMessage(
        code: code,
        content: 'Besok jam 09:00 ke ruang BK ya.',
        senderLabel: 'Bu Rina · Guru BK',
        asCounselor: true,
      );
      expect(msgRes.isOk, isTrue);

      final detail = await repo.getReportDetail(code);
      expect(
        detail.messages.any((m) => m.content.contains('09:00 ke ruang BK')),
        isTrue,
      );
    });
  });

  group('General AuthRepository login & special Guru BK account', () {
    test('normal login yields siswa and special BK email yields guruBk',
        () async {
      final repo = FullstackAuthRepository(
        client: null,
        prefs: LocalPreferencesService(null),
        secureStorage: DeviceSecureStorageService(),
      );

      final siswaRes = await repo.signInWithEmail(
        email: 'andi@gmail.com',
        password: 'password123',
      );
      expect(siswaRes.isOk, isTrue);
      final siswa = (siswaRes as Ok<StudentProfile>).value;
      expect(siswa.role, UserRole.siswa);
      expect(siswa.needsProfileSetup, isTrue);
      expect(siswa.className, isEmpty);
      expect(siswa.schoolName, isEmpty);

      final savedBiodata = await repo.saveProfileAndEnsureSession(
        siswa.copyWith(
          name: 'Andi Pratama',
          className: 'X-3',
          schoolName: 'SMAN 5 Bandung',
          isProfileCompleted: true,
        ),
      );
      expect(savedBiodata.isOk, isTrue);
      final completed = (savedBiodata as Ok<StudentProfile>).value;
      expect(completed.needsProfileSetup, isFalse);
      expect(completed.schoolName, 'SMAN 5 Bandung');

      final bkRes = await repo.signInWithEmail(
        email: specialCounselorEmail,
        password: 'password123',
      );
      expect(bkRes.isOk, isTrue);
      final bk = (bkRes as Ok<StudentProfile>).value;
      expect(bk.role, UserRole.guruBk);
      expect(bk.needsProfileSetup, isFalse);

      final blockedSignup = await repo.signUpWithEmail(
        email: specialCounselorEmail,
        password: 'password123',
        profile: completed,
      );
      expect(blockedSignup.isErr, isTrue);
    });
  });
}
