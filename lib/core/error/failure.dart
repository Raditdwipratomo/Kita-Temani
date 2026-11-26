sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Tidak ada koneksi internet.',
  ]);
}

final class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Terjadi kesalahan pada server.',
  ]);
}

final class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class SecurityFailure extends Failure {
  const SecurityFailure(super.message);
}
