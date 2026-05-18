/// Utilitas manipulasi String untuk Go-Dah.
/// Semua fungsi bersifat pure (tidak ada side effect) dan null-safe.
abstract final class StringUtils {
  // ── Trim & Clean ───────────────────────────────────────────────────

  /// Hapus spasi di awal dan akhir.
  static String trim(String value) => value.trim();

  /// Hapus semua spasi berlebihan di dalam kalimat.
  /// Contoh: "Go  Dah   App" → "Go Dah App"
  static String trimAll(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Hapus seluruh spasi (termasuk di tengah).
  /// Contoh: "355 C 7D" → "355C7D"
  static String removeAllSpaces(String value) =>
      value.replaceAll(' ', '');

  /// Hapus karakter non-alfanumerik.
  /// Contoh: "Go-Dah_App!" → "GoDahApp"
  static String alphanumericOnly(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  // ── Case conversion ────────────────────────────────────────────────

  /// "halo dunia" → "Halo Dunia"
  static String toTitleCase(String value) {
    if (value.isEmpty) return value;
    return value.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// "halo dunia" → "Halo dunia"
  static String toSentenceCase(String value) {
    if (value.isEmpty) return value;
    final trimmed = value.trim();
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  // ── Format Nomor HP ────────────────────────────────────────────────

  /// Normalkan nomor HP ke format internasional +62.
  /// "08123456789" → "+628123456789"
  /// "628123456789" → "+628123456789"
  static String normalizePhone(String phone) {
    final clean = removeAllSpaces(phone).replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.startsWith('+62')) return clean;
    if (clean.startsWith('62'))  return '+$clean';
    if (clean.startsWith('0'))   return '+62${clean.substring(1)}';
    return '+62$clean';
  }

  /// Format nomor HP untuk ditampilkan.
  /// "+628123456789" → "0812-3456-789"
  static String formatPhoneDisplay(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    final local = digits.startsWith('62') ? '0${digits.substring(2)}' : digits;
    if (local.length < 9) return local;
    // Format: 4-4-sisanya
    return '${local.substring(0, 4)}-${local.substring(4, 8)}-${local.substring(8)}';
  }

  // ── Format Mata Uang ───────────────────────────────────────────────

  /// Format angka ke format Rupiah.
  /// 15000 → "Rp 15.000"
  static String toRupiah(num amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .split('')
        .reversed
        .toList()
        .fold<List<String>>([], (acc, char) {
          acc.add(char);
          if (acc.length % 3 == 0 && acc.length != amount.toStringAsFixed(0).length) {
            acc.add('.');
          }
          return acc;
        })
        .reversed
        .join()
        .replaceAll(RegExp(r'^\.*'), '');
    return 'Rp $formatted';
  }

  /// Format compact: 1500000 → "Rp 1,5 jt"
  static String toRupiahCompact(num amount) {
    if (amount >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(1)} M';
    } else if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)} jt';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp ${amount.toStringAsFixed(0)}';
  }

  // ── Truncate ───────────────────────────────────────────────────────

  /// Potong teks panjang dan tambahkan ellipsis.
  /// truncate("Ini teks yang sangat panjang", 10) → "Ini teks y..."
  static String truncate(String value, int maxLength, {String ellipsis = '...'}) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}$ellipsis';
  }

  // ── Slug / ID ──────────────────────────────────────────────────────

  /// "Go-Dah App 2025" → "go-dah-app-2025"
  static String toSlug(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  // ── Validation helpers ─────────────────────────────────────────────

  static bool isEmail(String value) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(value.trim());

  static bool isPhoneNumber(String value) =>
      RegExp(r'^(\+62|62|0)[0-9]{8,12}$').hasMatch(removeAllSpaces(value));

  static bool isNullOrEmpty(String? value) =>
      value == null || value.trim().isEmpty;

  static bool isNotNullOrEmpty(String? value) => !isNullOrEmpty(value);

  // ── Initials (untuk avatar) ────────────────────────────────────────

  /// "Budi Santoso" → "BS"
  static String initials(String name, {int maxChars = 2}) {
    final words = trimAll(name).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return words
        .take(maxChars)
        .map((w) => w[0].toUpperCase())
        .join();
  }

  // ── Masking ────────────────────────────────────────────────────────

  /// Sembunyikan sebagian email: "budi@mail.com" → "b***@mail.com"
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final masked = local.length <= 1 ? local : '${local[0]}***';
    return '$masked@${parts[1]}';
  }

  /// Sembunyikan nomor HP: "08123456789" → "0812****789"
  static String maskPhone(String phone) {
    final clean = removeAllSpaces(phone);
    if (clean.length < 7) return clean;
    return '${clean.substring(0, 4)}****${clean.substring(clean.length - 3)}';
  }
}
