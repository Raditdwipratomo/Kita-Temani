import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/app/app.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';
import 'package:kitatemani/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/controllers/emergency_contacts_controller.dart';
import 'package:kitatemani/features/home/presentation/screens/home_screen.dart';
import 'package:kitatemani/features/panic/presentation/screens/panic_status_screen.dart';
import 'package:kitatemani/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:kitatemani/features/profile/presentation/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> scrollAndEnter(
    WidgetTester tester,
    Finder labelFinder,
    Finder fieldFinder,
    String text,
  ) async {
    await tester.scrollUntilVisible(
      labelFinder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(fieldFinder);
    await tester.pumpAndSettle();
    await tester.enterText(fieldFinder, text);
    await tester.pumpAndSettle();
  }

  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('StudentProfile entity extensions', () {
    test('serializes and deserializes detailed profile fields & defaults', () {
      final full = StudentProfile(
        id: 'stu-1',
        schoolId: defaultSchoolSlug,
        schoolName: 'SMAN 1 Nusantara',
        name: 'Radit Pratama',
        shortName: 'Radit',
        className: 'XI-MIPA 2',
        safeDaysCount: 5,
        counselorName: defaultCounselorName,
        email: 'radit@sekolah.id',
        isProfileCompleted: true,
        avatarPreset: 'owl_warm',
        gender: 'L',
        birthDate: DateTime(2009, 5, 14),
        educationLevel: 'SMA',
        homeroomTeacher: 'Pak Budi Santoso',
        phoneNumber: '0812-3456-7890',
        parentName: 'Ibu Sari',
        preferredContactMethod: 'whatsapp',
        safetyNote: 'Lebih nyaman konseling di pagi hari',
      );

      final roundTrip = StudentProfile.fromJson(full.toJson());
      expect(roundTrip.phoneNumber, '0812-3456-7890');
      expect(roundTrip.avatarPreset, 'owl_warm');
      expect(roundTrip.gender, 'L');
      expect(roundTrip.birthDate, DateTime(2009, 5, 14));
      expect(roundTrip.educationLevel, 'SMA');
      expect(roundTrip.homeroomTeacher, 'Pak Budi Santoso');
      expect(roundTrip.parentName, 'Ibu Sari');
      expect(roundTrip.preferredContactMethod, 'whatsapp');
      expect(roundTrip.safetyNote, 'Lebih nyaman konseling di pagi hari');
      expect(roundTrip.profileCompletenessPercent, 100);

      // Backward compatibility for legacy minimal JSON
      final legacy = StudentProfile.fromJson({
        'id': 'legacy-1',
        'name': 'Rafi Ahmad',
        'class_name': 'X-1',
        'school_name': 'SMA 2',
      });
      expect(legacy.avatarPreset, 'indigo');
      expect(legacy.preferredContactMethod, 'ruang_bk');
      expect(legacy.phoneNumber, isEmpty);
      expect(legacy.birthDate, isNull);
      expect(legacy.profileCompletenessPercent, 38);
    });
  });

  group('EditProfileScreen', () {
    testWidgets(
        'Menolak field wajib kosong & nomor telepon tidak valid dengan pesan inline',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Pastikan TIDAK ada field NIS / NISN
      expect(find.textContaining('NIS'), findsNothing);

      // Kosong semua -> error Nama lengkap wajib diisi
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();
      expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);

      // Isi wajib tapi nomor HP terlalu pendek
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Radit Pratama');
      await scrollAndEnter(
        tester,
        find.text('Nama sekolah *'),
        find.widgetWithText(TextField, 'Contoh: SMAN 1 Nusantara'),
        'SMAN 1 Nusantara',
      );
      await scrollAndEnter(
        tester,
        find.text('Kelas *'),
        find.widgetWithText(TextField, 'Contoh: XI-MIPA 2 / VIII-B'),
        'XI-MIPA 2',
      );
      await scrollAndEnter(
        tester,
        find.text('Nomor telepon / WhatsApp'),
        find.widgetWithText(TextField, 'Contoh: 0812-3456-7890'),
        '123',
      );

      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nomor telepon / WhatsApp harus berisi 9–15 digit angka.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Dari ProfileScreen ke EditProfileScreen, menyimpan detail lengkap termasuk nomor telepon & tampil di Profil',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const KitaTemaniApp(initialRoute: AppRoutes.profile),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ubah profil'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.textContaining('NIS'), findsNothing);

      // Pilih avatar maskot ramah
      await tester.tap(find.byTooltip('Maskot Ramah'));
      await tester.pumpAndSettle();

      // Identitas
      await scrollAndEnter(
        tester,
        find.text('Nama lengkap *'),
        find.widgetWithText(TextField, 'Contoh: Radit Pratama'),
        'Radit Pratama',
      );
      await scrollAndEnter(
        tester,
        find.text('Nama panggilan'),
        find.widgetWithText(TextField, 'Dipakai di sapaan Beranda & CurhAI'),
        'Radit',
      );
      await scrollAndTap(tester, find.text('Laki-laki'));

      // Data Sekolah
      await scrollAndTap(tester, find.text('SMA / MA'));
      await scrollAndEnter(
        tester,
        find.text('Nama sekolah *'),
        find.widgetWithText(TextField, 'Contoh: SMAN 1 Nusantara'),
        'SMAN 1 Nusantara',
      );
      await scrollAndEnter(
        tester,
        find.text('Kelas *'),
        find.widgetWithText(TextField, 'Contoh: XI-MIPA 2 / VIII-B'),
        'XI-MIPA 2',
      );
      await scrollAndEnter(
        tester,
        find.text('Nama wali kelas'),
        find.widgetWithText(TextField, 'Contoh: Pak Budi Santoso'),
        'Pak Budi Santoso',
      );

      // Kontak & Preferensi
      await scrollAndEnter(
        tester,
        find.text('Nomor telepon / WhatsApp'),
        find.widgetWithText(TextField, 'Contoh: 0812-3456-7890'),
        '081234567890',
      );
      await scrollAndEnter(
        tester,
        find.text('Nama orang tua / wali'),
        find.widgetWithText(TextField, 'Contoh: Ibu Sari (Opsional)'),
        'Ibu Sari',
      );
      expect(find.text('Preferensi cara dihubungi Guru BK'), findsNothing);
      expect(find.text('Catatan keselamatan / medis singkat'), findsNothing);

      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      // Kembali ke ProfileScreen dan data terbaru tampil rapi
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Radit Pratama'), findsOneWidget);
      expect(find.text('0812-3456-7890'), findsOneWidget);
      expect(find.text('SMA / MA'), findsOneWidget);

      final saved = container.read(studentProfileProvider);
      expect(saved.phoneNumber, '0812-3456-7890');
      expect(saved.shortName, 'Radit');
      expect(saved.educationLevel, 'SMA');
      expect(saved.homeroomTeacher, 'Pak Budi Santoso');
      expect(saved.parentName, 'Ibu Sari');
      expect(saved.avatarPreset, 'owl_warm');
    });

    testWidgets(
        'Konfirmasi Buang perubahan muncul saat tombol kembali ditekan setelah mengedit',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: EditProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Contoh: Radit Pratama'),
        'Nama Baru',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Buang perubahan?'), findsOneWidget);
      await tester.tap(find.text('Lanjut edit'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
    });

    testWidgets(
        'EditProfileScreen tampil rapi di Desktop 1280x800 & Mode Samar HomeScreen menyembunyikan avatar owl',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(studentProfileProvider.notifier).updateProfile(
            name: 'Siti Rahma',
            className: 'IX-A',
            schoolName: 'SMPN 3 Bandung',
            avatarPreset: 'owl_warm',
            isDisguisedMode: true,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OwlMascot), findsNothing);
    });
  });

  group('FullstackAuthRepository unauthenticated profile persistence', () {
    test(
        'saveProfileAndEnsureSession tanpa sesi auth aktif menyimpan lokal dan mengembalikan Ok',
        () async {
      final client = SupabaseClient(
        'https://invalid.example.test',
        'test-anon-key',
      );
      addTearDown(client.dispose);

      final sp = await SharedPreferences.getInstance();
      final repo = FullstackAuthRepository(
        client: client,
        prefs: LocalPreferencesService(sp),
        secureStorage: DeviceSecureStorageService(),
      );

      expect(client.auth.currentSession, isNull);

      const input = StudentProfile(
        id: 'guest-local',
        schoolId: defaultSchoolSlug,
        schoolName: 'SMAN 1 Nusantara',
        name: 'Radit Pratama',
        shortName: 'Radit',
        className: 'XI-MIPA 2',
        safeDaysCount: 0,
        counselorName: defaultCounselorName,
        avatarPreset: 'owl_warm',
        educationLevel: 'SMA',
        homeroomTeacher: 'Pak Budi Santoso',
        phoneNumber: '0812-3456-7890',
        parentName: 'Ibu Sari',
        preferredContactMethod: 'whatsapp',
        isProfileCompleted: true,
      );

      final res = await repo.saveProfileAndEnsureSession(input);
      expect(res.isOk, isTrue);
      final saved = (res as Ok<StudentProfile>).value;
      expect(saved.phoneNumber, '0812-3456-7890');
      expect(saved.avatarPreset, 'owl_warm');
      expect(saved.educationLevel, 'SMA');
      expect(saved.homeroomTeacher, 'Pak Budi Santoso');
      expect(saved.parentName, 'Ibu Sari');
      expect(saved.preferredContactMethod, 'whatsapp');
      expect(saved.isProfileCompleted, isTrue);

      final restored = await repo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.phoneNumber, '0812-3456-7890');
      expect(restored.avatarPreset, 'owl_warm');
      expect(restored.educationLevel, 'SMA');
      expect(restored.homeroomTeacher, 'Pak Budi Santoso');
      expect(restored.parentName, 'Ibu Sari');
      expect(restored.preferredContactMethod, 'whatsapp');
      expect(restored.isProfileCompleted, isTrue);
    });
  });

  group('Redesigned ProfileScreen & PanicStatusScreen responsive checks', () {
    testWidgets(
        'ProfileScreen redesain tampil rapi tanpa overflow di Mobile (390x844) dan Desktop (1280x800)',
        (tester) async {
      for (final viewport in const [Size(390, 844), Size(1280, 800)]) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;

        final container = ProviderContainer();
        container.read(studentProfileProvider.notifier).updateProfile(
              name: 'Gavin Nuno Nainggolan',
              className: 'XI-1',
              schoolName: 'SMAN 1 Nusantara',
              educationLevel: 'SMA',
              phoneNumber: '0812-3456-7890',
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Profil saya'), findsOneWidget);
        expect(find.text('Gavin Nuno Nainggolan'), findsOneWidget);
        expect(find.text('Kesiapan darurat'), findsOneWidget);
        expect(find.text('Keamanan & bantuan'), findsOneWidget);
        expect(find.text('Kontak darurat'), findsOneWidget);
        expect(find.text('Izin Aplikasi'), findsOneWidget);
        expect(find.text('Pusat bantuan'), findsOneWidget);
        expect(find.text('Selesai'), findsOneWidget);
        expect(find.text('Hari Aman'), findsNothing);
        expect(find.text('PENGATURAN KESELAMATAN'), findsNothing);

        await tester.scrollUntilVisible(
          find.text('Keluar dari akun'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Keluar dari akun'), findsOneWidget);
        expect(tester.takeException(), isNull);

        container.dispose();
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
        'PanicStatusScreen redesain tampil rapi dengan kontak utama di Mobile (390x844) dan Desktop (1280x800)',
        (tester) async {
      for (final viewport in const [Size(390, 844), Size(1280, 800)]) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;

        final container = ProviderContainer();
        await container
            .read(emergencyContactsControllerProvider.notifier)
            .saveContact(
              const EmergencyContact(
                id: 'ec-primary-1',
                name: 'ketua kelas',
                roleLabel: 'Wali Kelas',
                phone: '081381000577',
                isActive: true,
                isPrimary: true,
              ),
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: PanicStatusScreen()),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        expect(find.text('DARURAT AKTIF'), findsOneWidget);
        expect(find.text('Sinyal darurat terkirim'), findsOneWidget);
        expect(find.text('Guru BK ternotifikasi'), findsOneWidget);
        expect(find.text('Kirim WhatsApp ke ketua kelas'), findsOneWidget);
        expect(find.text('Pesan SOS siap kirim WhatsApp'), findsOneWidget);
        expect(find.text('Saya sudah aman · tahan 2 detik'), findsOneWidget);
        expect(find.textContaining('tombol hijau'), findsNothing);

        await tester.scrollUntilVisible(
          find.text('Chat WA Bu Rina'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Utama'), findsOneWidget);
        expect(find.text('Chat WA ketua kelas'), findsOneWidget);
        expect(find.text('Chat WA Bu Rina'), findsOneWidget);
        expect(find.text('Hubungi Bu Rina'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Verifikasi dialog Hentikan mode darurat? tampil rapi & dapat dibatalkan
        await tester.tap(find.text('Saya sudah aman · tahan 2 detik'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Hentikan mode darurat?'), findsOneWidget);
        expect(find.text('Ya, saya aman'), findsOneWidget);
        expect(find.text('Aman & Kabari WA'), findsOneWidget);
        expect(find.text('Tetap aktif'), findsOneWidget);
        await tester.tap(find.text('Tetap aktif'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Hentikan mode darurat?'), findsNothing);
        expect(tester.takeException(), isNull);

        // Unmount screen cleanly before disposing container to cancel timer
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
