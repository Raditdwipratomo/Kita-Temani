import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kitatemani/core/config/env.dart';
import 'package:kitatemani/core/error/failure.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const List<PartnerSchool> defaultPartnerSchools = [
  PartnerSchool(
    id: defaultSchoolSlug,
    slug: defaultSchoolSlug,
    name: defaultSchoolName,
    city: 'Jakarta',
    counselorName: defaultCounselorName,
    counselorPhone: defaultCounselorPhone,
  ),
];

class FullstackAuthRepository implements AuthRepository {
  FullstackAuthRepository({
    required SupabaseClient? client,
    required LocalPreferencesService prefs,
    SecureStorageService? secureStorage,
  })  : _client = client,
        _prefs = prefs,
        _secureStorage = secureStorage;

  static const String _profilePrefKey = 'kt_student_profile_json';

  final SupabaseClient? _client;
  final LocalPreferencesService _prefs;
  final SecureStorageService? _secureStorage;

  @override
  bool get hasActiveSession => _client?.auth.currentSession != null;

  @override
  Future<List<PartnerSchool>> fetchPartnerSchools() async {
    final client = _client;
    if (client != null) {
      try {
        final rows = await client
            .from('schools')
            .select('id, slug, name, city, counselor_name, counselor_phone')
            .order('name');
        final parsed = (rows as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(PartnerSchool.fromJson)
            .toList();
        if (parsed.isNotEmpty) return parsed;
      } on Object {
        // Fallback cleanly to built-in schools if offline or table empty.
      }
    }
    return defaultPartnerSchools;
  }

  Future<StudentProfile?> _readLocalProfile() async {
    final raw = _prefs.getString(_profilePrefKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return StudentProfile.fromJson(map);
      }
    } on Object {
      return null;
    }
    return null;
  }

  Future<void> _writeLocalProfile(StudentProfile profile) async {
    await _prefs.setString(_profilePrefKey, jsonEncode(profile.toJson()));
  }

  String _friendlyAuthMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Email atau kata sandi salah. Periksa kembali datamu.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek email atau nonaktifkan Confirm Email di Supabase Auth.';
    }
    if (lower.contains('user already registered')) {
      return 'Email ini sudah terdaftar. Silakan masuk di tab Masuk.';
    }
    if (lower.contains('password should be at least')) {
      return 'Kata sandi minimal 6 karakter.';
    }
    return raw;
  }

  String _profileCompletedKey(String uid) => 'kt_profile_completed_$uid';

  StudentProfile _buildDefaultProfileForEmail({
    required String userId,
    required String email,
    String initialName = '',
  }) {
    final normalizedEmail = email.trim();
    if (isSpecialCounselorEmail(normalizedEmail)) {
      return StudentProfile(
        id: userId,
        schoolId: defaultSchoolSlug,
        schoolName: defaultSchoolName,
        name: defaultCounselorName,
        shortName: 'Bu Rina',
        className: 'Ruang BK',
        safeDaysCount: 14,
        counselorName: defaultCounselorName,
        email: normalizedEmail,
        isProfileCompleted: true,
        role: UserRole.guruBk,
      );
    }
    final cleanName = initialName.trim();
    return StudentProfile(
      id: userId,
      schoolId: defaultSchoolSlug,
      schoolName: '',
      name: cleanName,
      shortName: cleanName.isNotEmpty ? cleanName.split(' ').first : '',
      className: '',
      safeDaysCount: 1,
      counselorName: defaultCounselorName,
      email: normalizedEmail,
      isProfileCompleted: false,
      role: UserRole.siswa,
    );
  }

  Future<StudentProfile?> _loadRemoteProfile(User user) async {
    final client = _client;
    if (client == null) return null;
    try {
      Map<String, dynamic>? row;
      var hasBiodataColumns = true;
      var hasDetailColumns = true;
      try {
        row = await client
            .from('profiles')
            .select(
              'id, school_id, name, short_name, class_name, school_name, is_profile_completed, email, role, is_private_mode, is_disguised_mode, safe_days_count, avatar_preset, avatar_url, gender, birth_date, education_level, homeroom_teacher, phone_number, parent_name, preferred_contact_method, safety_note, schools(slug, name, counselor_name, counselor_phone)',
            )
            .eq('id', user.id)
            .maybeSingle();
      } on PostgrestException {
        hasDetailColumns = false;
        try {
          row = await client
              .from('profiles')
              .select(
                'id, school_id, name, short_name, class_name, school_name, is_profile_completed, email, role, is_private_mode, is_disguised_mode, safe_days_count, schools(slug, name, counselor_name, counselor_phone)',
              )
              .eq('id', user.id)
              .maybeSingle();
        } on PostgrestException {
          hasBiodataColumns = false;
          row = await client
              .from('profiles')
              .select(
                'id, school_id, name, short_name, class_name, email, role, is_private_mode, is_disguised_mode, safe_days_count, schools(slug, name, counselor_name, counselor_phone)',
              )
              .eq('id', user.id)
              .maybeSingle();
        }
      }
      if (row == null) return null;

      final schoolData = row['schools'] is Map<String, dynamic>
          ? row['schools'] as Map<String, dynamic>
          : null;
      final local = await _readLocalProfile();
      final matchingLocal = local?.id == user.id ? local : null;
      final resolvedEmail = ((row['email'] ?? '').toString().isNotEmpty
              ? row['email']
              : (user.email ?? ''))
          .toString();
      final resolvedRole = isSpecialCounselorEmail(resolvedEmail)
          ? UserRole.guruBk
          : UserRole.fromWire(row['role']?.toString());
      final rawSchoolSlug =
          (schoolData?['slug'] ?? row['school_id'] ?? defaultSchoolSlug)
              .toString();

      final isCompleted = resolvedRole.isStaff
          ? true
          : (hasBiodataColumns
              ? (row['is_profile_completed'] == true)
              : _prefs.getBool(_profileCompletedKey(user.id)));

      final rawName = (row['name'] ?? '').toString().trim();
      final rawShortName = (row['short_name'] ?? '').toString().trim();
      final rawClass = (row['class_name'] ?? '').toString().trim();
      final rawSchoolName = hasBiodataColumns
          ? (row['school_name'] ?? '').toString().trim()
          : (matchingLocal?.schoolName.trim() ?? '');

      final effectiveName = resolvedRole.isStaff
          ? (rawName.isNotEmpty ? rawName : defaultCounselorName)
          : (isCompleted ? rawName : (rawName == 'Maya Putri' ? '' : rawName));
      final effectiveClass = resolvedRole.isStaff
          ? (rawClass.isNotEmpty ? rawClass : 'Ruang BK')
          : (isCompleted ? rawClass : '');
      final effectiveSchoolName = resolvedRole.isStaff
          ? (rawSchoolName.isNotEmpty
              ? rawSchoolName
              : (schoolData?['name'] ?? defaultSchoolName).toString())
          : (isCompleted
              ? (rawSchoolName.isNotEmpty
                  ? rawSchoolName
                  : (schoolData?['name'] ?? defaultSchoolName).toString())
              : '');

      var effectiveAvatarUrl = hasDetailColumns
          ? (row['avatar_url'] ?? '').toString().trim()
          : (matchingLocal?.avatarUrl ?? '');
      if (effectiveAvatarUrl.isNotEmpty &&
          !effectiveAvatarUrl.startsWith('http://') &&
          !effectiveAvatarUrl.startsWith('https://')) {
        try {
          effectiveAvatarUrl = await client.storage
              .from('avatars')
              .createSignedUrl(effectiveAvatarUrl, 3600 * 24 * 7);
        } on Object {
          // Keep stored path if signed URL generation fails offline.
        }
      }

      final rawBirth =
          hasDetailColumns ? (row['birth_date'] ?? '').toString().trim() : '';
      final parsedBirth = rawBirth.isNotEmpty
          ? DateTime.tryParse(rawBirth)
          : matchingLocal?.birthDate;

      final resolvedPreset = hasDetailColumns
          ? (row['avatar_preset'] ?? '').toString().trim()
          : (matchingLocal?.avatarPreset ?? '');
      final resolvedPreferred = hasDetailColumns
          ? (row['preferred_contact_method'] ?? '').toString().trim()
          : (matchingLocal?.preferredContactMethod ?? '');

      final profile = StudentProfile(
        id: user.id,
        schoolId:
            rawSchoolSlug == 'private-mode' ? defaultSchoolSlug : rawSchoolSlug,
        schoolName: effectiveSchoolName,
        name: effectiveName,
        shortName: rawShortName.isNotEmpty
            ? rawShortName
            : (effectiveName.isNotEmpty
                ? effectiveName.split(RegExp(r'\s+')).first
                : (resolvedRole.isStaff ? 'Bu Rina' : '')),
        className: effectiveClass,
        safeDaysCount: (row['safe_days_count'] as num?)?.toInt() ?? 1,
        counselorName:
            (schoolData?['counselor_name'] ?? defaultCounselorName).toString(),
        counselorPhone:
            (schoolData?['counselor_phone'] ?? '').toString().trim().isNotEmpty
                ? schoolData!['counselor_phone'].toString().trim()
                : defaultCounselorPhone,
        email: resolvedEmail,
        isGoogleConnected: true,
        isPrivateMode: false,
        isDisguisedMode: row['is_disguised_mode'] == true,
        hasTestedSms: matchingLocal?.hasTestedSms ?? false,
        isProfileCompleted: isCompleted,
        role: resolvedRole,
        avatarPreset: resolvedPreset.isNotEmpty ? resolvedPreset : 'indigo',
        avatarUrl: effectiveAvatarUrl,
        avatarBase64: matchingLocal?.avatarBase64 ?? '',
        gender: hasDetailColumns
            ? (row['gender'] ?? '').toString().trim()
            : (matchingLocal?.gender ?? ''),
        birthDate: parsedBirth,
        educationLevel: hasDetailColumns
            ? (row['education_level'] ?? '').toString().trim()
            : (matchingLocal?.educationLevel ?? ''),
        homeroomTeacher: hasDetailColumns
            ? (row['homeroom_teacher'] ?? '').toString().trim()
            : (matchingLocal?.homeroomTeacher ?? ''),
        phoneNumber: hasDetailColumns
            ? (row['phone_number'] ?? '').toString().trim()
            : (matchingLocal?.phoneNumber ?? ''),
        parentName: hasDetailColumns
            ? (row['parent_name'] ?? '').toString().trim()
            : (matchingLocal?.parentName ?? ''),
        preferredContactMethod:
            resolvedPreferred.isNotEmpty ? resolvedPreferred : 'ruang_bk',
        safetyNote: hasDetailColumns
            ? (row['safety_note'] ?? '').toString().trim()
            : (matchingLocal?.safetyNote ?? ''),
      );
      await _writeLocalProfile(profile);
      return profile;
    } on Object {
      return null;
    }
  }

  @override
  Future<StudentProfile?> restoreSession() async {
    final client = _client;
    if (client != null && client.auth.currentSession != null) {
      final user = client.auth.currentUser;
      if (user != null) {
        final remote = await _loadRemoteProfile(user);
        if (remote != null) return remote;

        final metaName = (user.userMetadata?['full_name'] ??
                user.userMetadata?['name'] ??
                '')
            .toString()
            .trim();
        final draft = _buildDefaultProfileForEmail(
          userId: user.id,
          email: user.email ?? '',
          initialName: metaName,
        );
        if (draft.role.isStaff) {
          final synced = await saveProfileAndEnsureSession(draft);
          if (synced case Ok(:final value)) {
            return value;
          }
        }
        await _writeLocalProfile(draft);
        return draft;
      }
    }
    return _readLocalProfile();
  }

  @override
  Future<Result<StudentProfile>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (password.length < 6) {
      return const Err(ValidationFailure('Kata sandi minimal 6 karakter.'));
    }
    final client = _client;
    if (client == null) {
      if (Env.useSupabase) {
        return const Err(
          NetworkFailure(
            'Layanan autentikasi belum terhubung. Periksa koneksi internet lalu coba lagi.',
          ),
        );
      }
      if (isSpecialCounselorEmail(normalizedEmail)) {
        final bk = _buildDefaultProfileForEmail(
          userId: 'counselor-1',
          email: normalizedEmail,
        ).copyWith(isGoogleConnected: true);
        await _writeLocalProfile(bk);
        return Ok(bk);
      }
      final existing = await _readLocalProfile();
      if (existing != null &&
          existing.email.trim().toLowerCase() ==
              normalizedEmail.toLowerCase() &&
          !existing.needsProfileSetup) {
        return Ok(existing);
      }
      final draft = _buildDefaultProfileForEmail(
        userId: 'student-1',
        email: normalizedEmail,
      ).copyWith(isGoogleConnected: true);
      await _writeLocalProfile(draft);
      return Ok(draft);
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return const Err(ServerFailure('Gagal masuk ke akun.'));
      }
      final loaded = await _loadRemoteProfile(user);
      if (loaded != null) {
        if (isSpecialCounselorEmail(user.email ?? normalizedEmail)) {
          return saveProfileAndEnsureSession(
            loaded.copyWith(role: UserRole.guruBk, isProfileCompleted: true),
          );
        }
        return Ok(loaded);
      }

      final metaName =
          (user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '')
              .toString()
              .trim();
      final draft = _buildDefaultProfileForEmail(
        userId: user.id,
        email: user.email ?? normalizedEmail,
        initialName: metaName,
      );
      if (draft.role.isStaff) {
        return saveProfileAndEnsureSession(draft);
      }
      await _writeLocalProfile(draft);
      return Ok(draft);
    } on AuthException catch (e) {
      return Err(ServerFailure(_friendlyAuthMessage(e.message)));
    } on Object {
      return const Err(NetworkFailure());
    }
  }

  @override
  Future<Result<StudentProfile>> signUpWithEmail({
    required String email,
    required String password,
    required StudentProfile profile,
  }) async {
    final normalizedEmail = email.trim();
    if (isSpecialCounselorEmail(normalizedEmail)) {
      return const Err(
        ServerFailure(
          'Email ini khusus akun Guru BK. Silakan masuk melalui tab Masuk.',
        ),
      );
    }

    final cleanStudent = _buildDefaultProfileForEmail(
      userId: profile.id,
      email: normalizedEmail,
      initialName: profile.name,
    ).copyWith(isGoogleConnected: true);

    final client = _client;
    if (client == null) {
      if (Env.useSupabase) {
        return const Err(
          NetworkFailure(
            'Layanan pendaftaran belum terhubung. Periksa koneksi internet lalu coba lagi.',
          ),
        );
      }
      await _writeLocalProfile(cleanStudent);
      return Ok(cleanStudent);
    }

    try {
      final res = await client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          if (cleanStudent.name.isNotEmpty) 'name': cleanStudent.name,
        },
      );
      final user = res.user;
      if (user == null) {
        return const Err(ServerFailure('Pendaftaran gagal dibuat.'));
      }
      if (res.session == null) {
        return const Err(
          ServerFailure(
            'Akun berhasil dibuat, namun Supabase meminta konfirmasi email. Cek inbox atau matikan "Confirm email" di Supabase Auth -> Providers -> Email, lalu masuk lewat tab Masuk.',
          ),
        );
      }
      final draft = cleanStudent.copyWith(id: user.id);
      await _writeLocalProfile(draft);
      return Ok(draft);
    } on AuthException catch (e) {
      return Err(ServerFailure(_friendlyAuthMessage(e.message)));
    } on Object {
      return const Err(NetworkFailure());
    }
  }

  @override
  Future<Result<bool>> signInWithGoogleOAuth() async {
    final client = _client;
    if (client == null) {
      return const Ok(false);
    }
    try {
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'id.kitatemani://login-callback',
      );
      return Ok(launched);
    } on AuthException catch (e) {
      return Err(ServerFailure(_friendlyAuthMessage(e.message)));
    } on Object {
      return const Err(NetworkFailure());
    }
  }

  @override
  Future<Result<StudentProfile>> saveProfileAndEnsureSession(
    StudentProfile profile,
  ) async {
    final trimmedName = profile.name.trim();
    final trimmedShort = profile.shortName.trim();
    final resolvedShort = trimmedShort.isNotEmpty
        ? trimmedShort
        : (trimmedName.isNotEmpty
            ? trimmedName.split(RegExp(r'\s+')).first
            : '');
    final trimmedClass = profile.className.trim();
    final trimmedSchool = profile.schoolName.trim();
    final trimmedPhone = profile.phoneNumber.trim();
    final computedCompleted = profile.role.isStaff ||
        (profile.isProfileCompleted &&
            trimmedName.isNotEmpty &&
            trimmedClass.isNotEmpty &&
            trimmedSchool.isNotEmpty);

    final normalizedProfile = profile.copyWith(
      schoolId: defaultSchoolSlug,
      schoolName: trimmedSchool.isNotEmpty
          ? trimmedSchool
          : (profile.role.isStaff ? defaultSchoolName : ''),
      name: trimmedName,
      shortName: resolvedShort,
      className: trimmedClass,
      phoneNumber: trimmedPhone,
      homeroomTeacher: profile.homeroomTeacher.trim(),
      parentName: profile.parentName.trim(),
      safetyNote: profile.safetyNote.trim(),
      counselorPhone: (profile.role.isStaff && trimmedPhone.isNotEmpty)
          ? trimmedPhone
          : profile.counselorPhone,
      isPrivateMode: false,
      isProfileCompleted: computedCompleted,
    );

    final birthDate = normalizedProfile.birthDate;
    final birthDateIso = birthDate != null
        ? '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}'
        : null;

    final client = _client;
    if (client != null && client.auth.currentSession != null) {
      try {
        final uid = client.auth.currentUser?.id ?? normalizedProfile.id;
        dynamic res;
        try {
          res = await client.rpc(
            'upsert_my_profile',
            params: {
              'p_name': normalizedProfile.name,
              'p_class_name': normalizedProfile.className,
              'p_school_slug': defaultSchoolSlug,
              'p_is_private_mode': false,
              'p_is_disguised_mode': normalizedProfile.isDisguisedMode,
              'p_role': normalizedProfile.role.wireValue,
              'p_email': normalizedProfile.email,
              'p_school_name': normalizedProfile.schoolName,
              'p_is_profile_completed': normalizedProfile.isProfileCompleted,
              'p_short_name': normalizedProfile.shortName,
              'p_avatar_preset': normalizedProfile.avatarPreset,
              'p_avatar_url': normalizedProfile.avatarUrl,
              'p_gender': normalizedProfile.gender,
              'p_birth_date': birthDateIso,
              'p_education_level': normalizedProfile.educationLevel,
              'p_homeroom_teacher': normalizedProfile.homeroomTeacher,
              'p_phone_number': normalizedProfile.phoneNumber,
              'p_parent_name': normalizedProfile.parentName,
              'p_preferred_contact_method':
                  normalizedProfile.preferredContactMethod,
              'p_safety_note': normalizedProfile.safetyNote,
            },
          );
        } on PostgrestException {
          try {
            res = await client.rpc(
              'upsert_my_profile',
              params: {
                'p_name': normalizedProfile.name,
                'p_class_name': normalizedProfile.className,
                'p_school_slug': defaultSchoolSlug,
                'p_is_private_mode': false,
                'p_is_disguised_mode': normalizedProfile.isDisguisedMode,
                'p_role': normalizedProfile.role.wireValue,
                'p_email': normalizedProfile.email,
                'p_school_name': normalizedProfile.schoolName,
                'p_is_profile_completed': normalizedProfile.isProfileCompleted,
              },
            );
          } on PostgrestException {
            res = await client.rpc(
              'upsert_my_profile',
              params: {
                'p_name': normalizedProfile.name,
                'p_class_name': normalizedProfile.className,
                'p_school_slug': defaultSchoolSlug,
                'p_is_private_mode': false,
                'p_is_disguised_mode': normalizedProfile.isDisguisedMode,
                'p_role': normalizedProfile.role.wireValue,
                'p_email': normalizedProfile.email,
              },
            );
          }
        }

        final resolvedRole = res is Map && res['role'] != null
            ? UserRole.fromWire(res['role'].toString())
            : (isSpecialCounselorEmail(normalizedProfile.email)
                ? UserRole.guruBk
                : normalizedProfile.role);
        final resolvedSchoolName = normalizedProfile.schoolName.isNotEmpty
            ? normalizedProfile.schoolName
            : (res is Map && res['school_name'] != null
                ? res['school_name'].toString()
                : defaultSchoolName);
        final resolvedCounselorPhone = (resolvedRole.isStaff &&
                trimmedPhone.isNotEmpty)
            ? trimmedPhone
            : (res is Map &&
                    (res['counselor_phone'] ?? '').toString().trim().isNotEmpty
                ? res['counselor_phone'].toString().trim()
                : defaultCounselorPhone);
        final updated = normalizedProfile.copyWith(
          id: uid,
          schoolName: resolvedSchoolName,
          counselorName: res is Map && res['counselor_name'] != null
              ? res['counselor_name'].toString()
              : defaultCounselorName,
          counselorPhone: resolvedCounselorPhone,
          isProfileCompleted: resolvedRole.isStaff || computedCompleted,
          role: resolvedRole,
        );
        await _prefs.setBool(
          _profileCompletedKey(uid),
          updated.isProfileCompleted,
        );
        await _writeLocalProfile(updated);
        return Ok(updated);
      } on AuthException catch (e) {
        await _writeLocalProfile(normalizedProfile);
        return Err(ServerFailure(_friendlyAuthMessage(e.message)));
      } on PostgrestException catch (e) {
        await _writeLocalProfile(normalizedProfile);
        return Err(ServerFailure(e.message));
      } on Object {
        // Still save locally so student workflow continues cleanly offline.
      }
    }

    await _prefs.setBool(
      _profileCompletedKey(normalizedProfile.id),
      normalizedProfile.isProfileCompleted,
    );
    await _writeLocalProfile(normalizedProfile);
    return Ok(normalizedProfile);
  }

  @override
  Future<Result<String>> uploadAvatar(Uint8List bytes) async {
    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null || bytes.isEmpty) {
      return const Ok('');
    }
    try {
      final path = '$uid/avatar.jpg';
      await client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      final signed = await client.storage
          .from('avatars')
          .createSignedUrl(path, 3600 * 24 * 30);
      return Ok(signed);
    } on Object {
      return const Ok('');
    }
  }

  @override
  Future<Result<void>> updatePassword(String newPassword) async {
    if (newPassword.trim().length < 6) {
      return const Err(ValidationFailure('Kata sandi minimal 6 karakter.'));
    }
    final client = _client;
    if (client == null || client.auth.currentSession == null) {
      return const Err(
        ValidationFailure(
          'Ubah kata sandi hanya tersedia saat masuk dengan akun email online.',
        ),
      );
    }
    try {
      await client.auth.updateUser(UserAttributes(password: newPassword));
      return const Ok(null);
    } on AuthException catch (e) {
      return Err(ServerFailure(_friendlyAuthMessage(e.message)));
    } on Object {
      return const Err(NetworkFailure());
    }
  }

  @override
  Future<void> signOut() async {
    await _prefs.remove(_profilePrefKey);
    await _prefs.removeByPrefix('kt_reports_');
    await _prefs.removeByPrefix('kt_offline_report_queue_');
    await _prefs.removeByPrefix('kt_report_history_');
    await _prefs.removeByPrefix('kt_report_messages_');
    await _secureStorage?.clearAll();

    final client = _client;
    if (client != null && client.auth.currentSession != null) {
      try {
        await client.auth.signOut();
      } on Object {
        // Ignore network errors during local logout.
      }
    }
  }
}
