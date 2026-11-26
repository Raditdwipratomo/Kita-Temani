const String defaultSchoolSlug = 'sman1-nusantara';
const String defaultSchoolName = 'SMAN 1 Nusantara';
const String defaultCounselorName = 'Bu Rina, S.Pd.';
const String defaultCounselorPhone = '089686899447';
const String specialCounselorEmail = 'bk@kitatemani.id';

bool isSpecialCounselorEmail(String email) =>
    email.trim().toLowerCase() == specialCounselorEmail;

enum UserRole {
  siswa('siswa', 'Siswa'),
  guruBk('guru_bk', 'Guru BK'),
  waliKelas('wali_kelas', 'Wali Kelas');

  const UserRole(this.wireValue, this.label);
  final String wireValue;
  final String label;

  bool get isStaff => this == UserRole.guruBk || this == UserRole.waliKelas;

  static UserRole fromWire(String? value) {
    return switch (value) {
      'guru_bk' => UserRole.guruBk,
      'wali_kelas' => UserRole.waliKelas,
      _ => UserRole.siswa,
    };
  }
}

class PartnerSchool {
  const PartnerSchool({
    required this.id,
    required this.slug,
    required this.name,
    required this.city,
    required this.counselorName,
    this.counselorPhone,
  });

  final String id;
  final String slug;
  final String name;
  final String city;
  final String counselorName;
  final String? counselorPhone;

  String get displayLabel => '$name · $city';

  factory PartnerSchool.fromJson(Map<String, dynamic> json) {
    return PartnerSchool(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? defaultSchoolName).toString(),
      city: (json['city'] ?? 'Indonesia').toString(),
      counselorName: (json['counselor_name'] ?? 'Guru BK').toString(),
      counselorPhone: json['counselor_phone']?.toString(),
    );
  }
}

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.name,
    required this.shortName,
    required this.className,
    required this.safeDaysCount,
    required this.counselorName,
    this.counselorPhone = defaultCounselorPhone,
    this.email = '',
    this.isGoogleConnected = false,
    this.isPrivateMode = false,
    this.isDisguisedMode = false,
    this.hasTestedSms = false,
    this.isProfileCompleted = false,
    this.role = UserRole.siswa,
    this.avatarPreset = 'indigo',
    this.avatarUrl = '',
    this.avatarBase64 = '',
    this.gender = '',
    this.birthDate,
    this.educationLevel = '',
    this.homeroomTeacher = '',
    this.phoneNumber = '',
    this.parentName = '',
    this.preferredContactMethod = 'ruang_bk',
    this.safetyNote = '',
  });

  final String id;
  final String schoolId;
  final String schoolName;
  final String name;
  final String shortName;
  final String className;
  final int safeDaysCount;
  final String counselorName;
  final String counselorPhone;
  final String email;
  final bool isGoogleConnected;
  final bool isPrivateMode;
  final bool isDisguisedMode;
  final bool hasTestedSms;
  final bool isProfileCompleted;
  final UserRole role;
  final String avatarPreset;
  final String avatarUrl;
  final String avatarBase64;
  final String gender;
  final DateTime? birthDate;
  final String educationLevel;
  final String homeroomTeacher;
  final String phoneNumber;
  final String parentName;
  final String preferredContactMethod;
  final String safetyNote;

  bool get needsProfileSetup =>
      !role.isStaff &&
      (!isProfileCompleted ||
          name.trim().isEmpty ||
          className.trim().isEmpty ||
          schoolName.trim().isEmpty);

  bool get hasCustomPhoto =>
      avatarBase64.trim().isNotEmpty || avatarUrl.trim().isNotEmpty;

  String get genderLabel => switch (gender.trim()) {
        'L' => 'Laki-laki',
        'P' => 'Perempuan',
        'other' => 'Memilih tidak menyebutkan',
        _ => '',
      };

  String get educationLevelLabel =>
      switch (educationLevel.trim().toUpperCase()) {
        'SMP' => 'SMP / MTs',
        'SMA' || 'MA' => 'SMA / MA',
        'SMK' => 'SMK',
        _ => '',
      };

  String get preferredContactLabel => switch (preferredContactMethod.trim()) {
        'whatsapp' => 'Lewat WhatsApp',
        'orang_tua' => 'Melalui Orang Tua',
        'aplikasi' => 'Lewat Aplikasi Saja',
        _ => 'Temui di Ruang BK',
      };

  String get effectiveShortName {
    final nick = shortName.trim();
    if (nick.isNotEmpty) return nick;
    final full = name.trim();
    if (full.isEmpty) return '';
    return full.split(RegExp(r'\s+')).first;
  }

  int get profileCompletenessPercent {
    if (role.isStaff) {
      final checks = [
        name.trim().isNotEmpty,
        className.trim().isNotEmpty,
        schoolName.trim().isNotEmpty,
        phoneNumber.trim().isNotEmpty || counselorPhone.trim().isNotEmpty,
      ];
      final done = checks.where((ok) => ok).length;
      return ((done / checks.length) * 100).round();
    }
    final checks = [
      name.trim().isNotEmpty,
      className.trim().isNotEmpty,
      schoolName.trim().isNotEmpty,
      phoneNumber.trim().isNotEmpty,
      educationLevel.trim().isNotEmpty,
      gender.trim().isNotEmpty,
      birthDate != null,
      parentName.trim().isNotEmpty ||
          homeroomTeacher.trim().isNotEmpty ||
          safetyNote.trim().isNotEmpty,
    ];
    final done = checks.where((ok) => ok).length;
    return ((done / checks.length) * 100).round();
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'KT';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  String get schoolBadgeLabel {
    if (role.isStaff) {
      final labelSchool =
          schoolName.trim().isNotEmpty ? schoolName : defaultSchoolName;
      return '${role.label} · $labelSchool';
    }
    if (className.trim().isNotEmpty && schoolName.trim().isNotEmpty) {
      return '$className · $schoolName';
    }
    if (schoolName.trim().isNotEmpty) return schoolName;
    if (className.trim().isNotEmpty) return className;
    return 'Siswa';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'school_name': schoolName,
        'name': name,
        'short_name': shortName,
        'class_name': className,
        'safe_days_count': safeDaysCount,
        'counselor_name': counselorName,
        'counselor_phone': counselorPhone,
        'email': email,
        'is_google_connected': isGoogleConnected,
        'is_private_mode': isPrivateMode,
        'is_disguised_mode': isDisguisedMode,
        'has_tested_sms': hasTestedSms,
        'is_profile_completed': isProfileCompleted,
        'role': role.wireValue,
        'avatar_preset': avatarPreset,
        'avatar_url': avatarUrl,
        'avatar_base64': avatarBase64,
        'gender': gender,
        'birth_date': birthDate?.toIso8601String(),
        'education_level': educationLevel,
        'homeroom_teacher': homeroomTeacher,
        'phone_number': phoneNumber,
        'parent_name': parentName,
        'preferred_contact_method': preferredContactMethod,
        'safety_note': safetyNote,
      };

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    final fullName = (json['name'] ?? '').toString();
    final shortRaw = (json['short_name'] ?? '').toString().trim();
    final rawBirth = (json['birth_date'] ?? '').toString().trim();
    final parsedBirth =
        rawBirth.isNotEmpty ? DateTime.tryParse(rawBirth) : null;
    final rawPreset = (json['avatar_preset'] ?? '').toString().trim();
    final rawPreferred =
        (json['preferred_contact_method'] ?? '').toString().trim();

    return StudentProfile(
      id: (json['id'] ?? 'student-1').toString(),
      schoolId: (json['school_id'] ?? defaultSchoolSlug).toString(),
      schoolName: (json['school_name'] ?? '').toString(),
      name: fullName,
      shortName: shortRaw.isNotEmpty
          ? shortRaw
          : (fullName.trim().isNotEmpty
              ? fullName.trim().split(RegExp(r'\s+')).first
              : ''),
      className: (json['class_name'] ?? '').toString(),
      safeDaysCount: (json['safe_days_count'] as num?)?.toInt() ?? 0,
      counselorName:
          (json['counselor_name'] ?? defaultCounselorName).toString(),
      counselorPhone:
          (json['counselor_phone'] ?? '').toString().trim().isNotEmpty
              ? json['counselor_phone'].toString().trim()
              : defaultCounselorPhone,
      email: (json['email'] ?? '').toString(),
      isGoogleConnected: json['is_google_connected'] as bool? ?? false,
      isPrivateMode: json['is_private_mode'] as bool? ?? false,
      isDisguisedMode: json['is_disguised_mode'] as bool? ?? false,
      hasTestedSms: json['has_tested_sms'] as bool? ?? false,
      isProfileCompleted: json['is_profile_completed'] as bool? ?? false,
      role: UserRole.fromWire(json['role']?.toString()),
      avatarPreset: rawPreset.isNotEmpty ? rawPreset : 'indigo',
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      avatarBase64: (json['avatar_base64'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      birthDate: parsedBirth,
      educationLevel: (json['education_level'] ?? '').toString(),
      homeroomTeacher: (json['homeroom_teacher'] ?? '').toString(),
      phoneNumber: (json['phone_number'] ?? '').toString(),
      parentName: (json['parent_name'] ?? '').toString(),
      preferredContactMethod:
          rawPreferred.isNotEmpty ? rawPreferred : 'ruang_bk',
      safetyNote: (json['safety_note'] ?? '').toString(),
    );
  }

  StudentProfile copyWith({
    String? id,
    String? schoolId,
    String? schoolName,
    String? name,
    String? shortName,
    String? className,
    int? safeDaysCount,
    String? counselorName,
    String? counselorPhone,
    String? email,
    bool? isGoogleConnected,
    bool? isPrivateMode,
    bool? isDisguisedMode,
    bool? hasTestedSms,
    bool? isProfileCompleted,
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
    return StudentProfile(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      className: className ?? this.className,
      safeDaysCount: safeDaysCount ?? this.safeDaysCount,
      counselorName: counselorName ?? this.counselorName,
      counselorPhone: counselorPhone ?? this.counselorPhone,
      email: email ?? this.email,
      isGoogleConnected: isGoogleConnected ?? this.isGoogleConnected,
      isPrivateMode: isPrivateMode ?? this.isPrivateMode,
      isDisguisedMode: isDisguisedMode ?? this.isDisguisedMode,
      hasTestedSms: hasTestedSms ?? this.hasTestedSms,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      role: role ?? this.role,
      avatarPreset: avatarPreset ?? this.avatarPreset,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      gender: gender ?? this.gender,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      educationLevel: educationLevel ?? this.educationLevel,
      homeroomTeacher: homeroomTeacher ?? this.homeroomTeacher,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      parentName: parentName ?? this.parentName,
      preferredContactMethod:
          preferredContactMethod ?? this.preferredContactMethod,
      safetyNote: safetyNote ?? this.safetyNote,
    );
  }
}
