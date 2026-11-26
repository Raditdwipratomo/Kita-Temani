import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FullstackAuthRepository(
    client: ref.watch(supabaseClientProvider),
    prefs: ref.watch(localPreferencesServiceProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});

final partnerSchoolsProvider = FutureProvider<List<PartnerSchool>>((ref) async {
  return ref.watch(authRepositoryProvider).fetchPartnerSchools();
});

class StudentProfileNotifier extends StateNotifier<StudentProfile> {
  StudentProfileNotifier(this._repo, this._prefs)
      : super(
          StudentProfile(
            id: '',
            schoolId: defaultSchoolSlug,
            schoolName: '',
            name: '',
            shortName: '',
            className: '',
            safeDaysCount: 0,
            counselorName: defaultCounselorName,
            email: '',
            isGoogleConnected: false,
            isPrivateMode: false,
            isDisguisedMode: false,
            hasTestedSms: _prefs.getBool('kt_has_tested_sms'),
            isProfileCompleted: false,
          ),
        );

  final AuthRepository _repo;
  final LocalPreferencesService _prefs;

  Future<bool> restoreSessionIfAuthenticated() async {
    if (!_repo.hasActiveSession) return false;
    final restored = await _repo.restoreSession();
    if (restored != null) {
      state = restored;
      return true;
    }
    return false;
  }

  void connectGoogle({
    String email = '',
    String? name,
  }) {
    final trimmedName = name?.trim();
    state = state.copyWith(
      email: email,
      isGoogleConnected: true,
      name: (trimmedName != null && trimmedName.isNotEmpty)
          ? trimmedName
          : state.name,
      shortName: (trimmedName != null && trimmedName.isNotEmpty)
          ? trimmedName.split(' ').first
          : state.shortName,
    );
  }

  Future<Result<bool>> launchGoogleOAuth() {
    return _repo.signInWithGoogleOAuth();
  }

  Future<Result<StudentProfile>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _repo.signInWithEmail(email: email, password: password);
    if (res case Ok(:final value)) {
      state = value;
    }
    return res;
  }

  Future<Result<StudentProfile>> signUpWithEmail({
    required String email,
    required String password,
    required StudentProfile profile,
  }) async {
    final res = await _repo.signUpWithEmail(
      email: email,
      password: password,
      profile: profile,
    );
    if (res case Ok(:final value)) {
      state = value;
    }
    return res;
  }

  void prepareBiodataDraft({
    required String email,
    String initialName = '',
    bool isGoogleConnected = false,
  }) {
    final trimmed = initialName.trim();
    state = StudentProfile(
      id: 'student-draft',
      schoolId: defaultSchoolSlug,
      schoolName: '',
      name: trimmed,
      shortName: trimmed.isNotEmpty ? trimmed.split(' ').first : '',
      className: '',
      safeDaysCount: 1,
      counselorName: defaultCounselorName,
      email: email.trim(),
      isGoogleConnected: isGoogleConnected,
      isProfileCompleted: false,
      role: UserRole.siswa,
    );
  }

  Future<Result<StudentProfile>> saveProfileAndSync({
    String? name,
    String? shortName,
    String? className,
    String? schoolName,
    String? schoolId,
    String? counselorName,
    String? counselorPhone,
    bool? isPrivateMode,
    bool? isDisguisedMode,
    bool? isGoogleConnected,
    bool? isProfileCompleted,
    String? email,
    UserRole? role,
    String? avatarPreset,
    String? avatarUrl,
    String? avatarBase64,
    String? gender,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? educationLevel,
    String? homeroomTeacher,
    String? phoneNumber,
    String? parentName,
    String? preferredContactMethod,
    String? safetyNote,
  }) async {
    updateProfile(
      name: name,
      shortName: shortName,
      className: className,
      schoolName: schoolName,
      schoolId: schoolId,
      counselorName: counselorName,
      counselorPhone: counselorPhone,
      isPrivateMode: isPrivateMode,
      isDisguisedMode: isDisguisedMode,
      isGoogleConnected: isGoogleConnected,
      isProfileCompleted: isProfileCompleted,
      email: email,
      role: role,
      avatarPreset: avatarPreset,
      avatarUrl: avatarUrl,
      avatarBase64: avatarBase64,
      gender: gender,
      birthDate: birthDate,
      clearBirthDate: clearBirthDate,
      educationLevel: educationLevel,
      homeroomTeacher: homeroomTeacher,
      phoneNumber: phoneNumber,
      parentName: parentName,
      preferredContactMethod: preferredContactMethod,
      safetyNote: safetyNote,
    );
    final res = await _repo.saveProfileAndEnsureSession(state);
    if (res case Ok(:final value)) {
      state = value;
    }
    return res;
  }

  Future<Result<String>> uploadAvatar(Uint8List bytes) {
    return _repo.uploadAvatar(bytes);
  }

  Future<Result<void>> updatePassword(String newPassword) {
    return _repo.updatePassword(newPassword);
  }

  void updateProfile({
    String? name,
    String? shortName,
    String? className,
    String? schoolName,
    String? schoolId,
    String? counselorName,
    String? counselorPhone,
    bool? isPrivateMode,
    bool? isDisguisedMode,
    bool? isGoogleConnected,
    bool? isProfileCompleted,
    String? email,
    UserRole? role,
    String? avatarPreset,
    String? avatarUrl,
    String? avatarBase64,
    String? gender,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? educationLevel,
    String? homeroomTeacher,
    String? phoneNumber,
    String? parentName,
    String? preferredContactMethod,
    String? safetyNote,
  }) {
    final resolvedName =
        (name != null && name.trim().isNotEmpty) ? name.trim() : state.name;
    final String resolvedShort;
    if (shortName != null) {
      resolvedShort = shortName.trim().isNotEmpty
          ? shortName.trim()
          : (resolvedName.trim().isNotEmpty
              ? resolvedName.trim().split(RegExp(r'\s+')).first
              : '');
    } else if (state.shortName.trim().isNotEmpty) {
      resolvedShort = state.shortName.trim();
    } else {
      resolvedShort = resolvedName.trim().isNotEmpty
          ? resolvedName.trim().split(RegExp(r'\s+')).first
          : '';
    }
    final resolvedClass = (className != null && className.trim().isNotEmpty)
        ? className.trim()
        : state.className;

    if (isDisguisedMode != null) {
      unawaited(_prefs.setBool('kt_disguised_mode', isDisguisedMode));
    }

    state = state.copyWith(
      name: resolvedName,
      shortName: resolvedShort,
      className: resolvedClass,
      schoolName: schoolName ?? state.schoolName,
      schoolId: schoolId ?? state.schoolId,
      counselorName: counselorName ?? state.counselorName,
      counselorPhone: counselorPhone ?? state.counselorPhone,
      isPrivateMode: isPrivateMode ?? state.isPrivateMode,
      isDisguisedMode: isDisguisedMode ?? state.isDisguisedMode,
      isGoogleConnected: isGoogleConnected ?? state.isGoogleConnected,
      isProfileCompleted: isProfileCompleted ?? state.isProfileCompleted,
      email: email ?? state.email,
      role: role ?? state.role,
      avatarPreset: avatarPreset ?? state.avatarPreset,
      avatarUrl: avatarUrl ?? state.avatarUrl,
      avatarBase64: avatarBase64 ?? state.avatarBase64,
      gender: gender ?? state.gender,
      birthDate: birthDate,
      clearBirthDate: clearBirthDate,
      educationLevel: educationLevel ?? state.educationLevel,
      homeroomTeacher: homeroomTeacher ?? state.homeroomTeacher,
      phoneNumber: phoneNumber ?? state.phoneNumber,
      parentName: parentName ?? state.parentName,
      preferredContactMethod:
          preferredContactMethod ?? state.preferredContactMethod,
      safetyNote: safetyNote ?? state.safetyNote,
    );
  }

  Future<void> toggleDisguisedMode(bool value) async {
    await _prefs.setBool('kt_disguised_mode', value);
    state = state.copyWith(isDisguisedMode: value);
    unawaited(_repo.saveProfileAndEnsureSession(state));
  }

  Future<void> markSmsTested() async {
    await _prefs.setBool('kt_has_tested_sms', true);
    state = state.copyWith(hasTestedSms: true);
  }

  Future<void> signOut() async {
    await _prefs.remove('kt_disguised_mode');
    await _prefs.remove('kt_has_tested_sms');
    await _repo.signOut();
    state = const StudentProfile(
      id: 'student-1',
      schoolId: defaultSchoolSlug,
      schoolName: '',
      name: '',
      shortName: '',
      className: '',
      safeDaysCount: 1,
      counselorName: defaultCounselorName,
      email: '',
      isGoogleConnected: false,
      isProfileCompleted: false,
    );
  }
}

final studentProfileProvider =
    StateNotifierProvider<StudentProfileNotifier, StudentProfile>(
  (ref) => StudentProfileNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(localPreferencesServiceProvider),
  ),
);
