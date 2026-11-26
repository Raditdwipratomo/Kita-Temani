import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/core/error/failure.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/presentation/screens/school_login_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Auth password & bypass security', () {
    test(
      'rejects wrong random password for Guru BK and Siswa when Supabase client is active',
      () async {
        final mockClient = _MockSupabaseClient();
        final mockAuth = _MockGoTrueClient();
        when(() => mockClient.auth).thenReturn(mockAuth);
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const AuthException('Invalid login credentials'));

        final repo = FullstackAuthRepository(
          client: mockClient,
          prefs: LocalPreferencesService(await SharedPreferences.getInstance()),
          secureStorage: InMemorySecureStorageService(),
        );

        final bkWrong = await repo.signInWithEmail(
          email: specialCounselorEmail,
          password: 'random-wrong-password',
        );
        expect(bkWrong, isA<Err<StudentProfile>>());
        expect(
          (bkWrong as Err<StudentProfile>).failure,
          isA<ServerFailure>(),
        );

        final studentWrong = await repo.signInWithEmail(
          email: 'siswa@gmail.com',
          password: 'random-wrong-password',
        );
        expect(studentWrong, isA<Err<StudentProfile>>());
        expect(
          (studentWrong as Err<StudentProfile>).failure,
          isA<ServerFailure>(),
        );
      },
    );

    test(
      'rejects network failures for Guru BK instead of falling back to local counselor bypass',
      () async {
        final mockClient = _MockSupabaseClient();
        final mockAuth = _MockGoTrueClient();
        when(() => mockClient.auth).thenReturn(mockAuth);
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception('network timeout'));

        final repo = FullstackAuthRepository(
          client: mockClient,
          prefs: LocalPreferencesService(await SharedPreferences.getInstance()),
          secureStorage: InMemorySecureStorageService(),
        );

        final bkNetErr = await repo.signInWithEmail(
          email: specialCounselorEmail,
          password: 'any-password-123',
        );
        expect(bkNetErr, isA<Err<StudentProfile>>());
        expect(
          (bkNetErr as Err<StudentProfile>).failure,
          isA<NetworkFailure>(),
        );
      },
    );

    test(
      'rejects passwords shorter than 6 characters before auth request',
      () async {
        final repo = FullstackAuthRepository(
          client: null,
          prefs: LocalPreferencesService(await SharedPreferences.getInstance()),
          secureStorage: InMemorySecureStorageService(),
        );

        final shortBk = await repo.signInWithEmail(
          email: specialCounselorEmail,
          password: '123',
        );
        expect(shortBk, isA<Err<StudentProfile>>());
        expect(
          (shortBk as Err<StudentProfile>).failure,
          isA<ValidationFailure>(),
        );
      },
    );

    testWidgets(
      'SchoolLoginScreen does not expose one-tap Guru BK or passwordless student bypass buttons',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: SchoolLoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Masuk sebagai Guru BK (bk@kitatemani.id)'),
          findsNothing,
        );
        expect(
          find.text('Masuk cepat sebagai Siswa tanpa sandi'),
          findsNothing,
        );
      },
    );
  });
}
