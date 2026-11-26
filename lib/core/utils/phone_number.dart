abstract final class PhoneNumber {
  /// Mengubah nomor lokal seperti "0857 1122 33" atau "+62 857-1122-33"
  /// menjadi format internasional "62857112233".
  static String toInternational(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('0')) {
      return '62${digits.substring(1)}';
    }
    if (digits.startsWith('8')) {
      return '62$digits';
    }
    return digits;
  }

  /// Menampilkan nomor dengan format yang mudah dibaca, misalnya "0813-9876-5432".
  static String formatDisplay(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) {
      digits = '0${digits.substring(2)}';
    } else if (digits.startsWith('8')) {
      digits = '0$digits';
    }
    if (digits.length <= 4) return digits;
    if (digits.length <= 8) {
      return '${digits.substring(0, 4)}-${digits.substring(4)}';
    }
    return '${digits.substring(0, 4)}-${digits.substring(4, 8)}-${digits.substring(8)}';
  }
}
