abstract final class DateFormatter {
  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<String> _fullMonths = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  /// Menghasilkan format tampilan seperti "27 Okt, 10:24".
  static String formatDisplay(DateTime date) {
    return '${dayMonth(date)}, ${timeHHmm(date)}';
  }

  /// Menghasilkan format pendek Bahasa Indonesia seperti "27 Okt".
  static String dayMonth(DateTime date) {
    final month = _shortMonths[date.month - 1];
    return '${date.day} $month';
  }

  /// Menghasilkan format tanggal pendek dengan tahun, misalnya "27 Okt 2026".
  static String shortDateYear(DateTime date) {
    return '${dayMonth(date)} ${date.year}';
  }

  /// Menghasilkan format tanggal lengkap Bahasa Indonesia, misalnya "27 Oktober 2026".
  static String fullDate(DateTime date) {
    final month = _fullMonths[date.month - 1];
    return '${date.day} $month ${date.year}';
  }

  /// Menghasilkan format jam seperti "10:24".
  static String timeHHmm(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Menghasilkan durasi mm:ss dari detik, misalnya "00:12".
  static String durationMmSs(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
