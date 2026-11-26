import 'dart:typed_data';

import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';

abstract interface class AuthRepository {
  bool get hasActiveSession;
  Future<List<PartnerSchool>> fetchPartnerSchools();
  Future<StudentProfile?> restoreSession();
  Future<Result<StudentProfile>> signInWithEmail({
    required String email,
    required String password,
  });
  Future<Result<StudentProfile>> signUpWithEmail({
    required String email,
    required String password,
    required StudentProfile profile,
  });
  Future<Result<bool>> signInWithGoogleOAuth();
  Future<Result<StudentProfile>> saveProfileAndEnsureSession(
    StudentProfile profile,
  );
  Future<Result<String>> uploadAvatar(Uint8List bytes);
  Future<Result<void>> updatePassword(String newPassword);
  Future<void> signOut();
}
