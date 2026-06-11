abstract final class StringUtils {

  static String trim(String value) => value.trim();

  static String trimAll(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String removeAllSpaces(String value) =>
      value.replaceAll(' ', '');

  static String alphanumericOnly(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');


  static String toTitleCase(String value) {
    if (value.isEmpty) return value;
    return value.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String toSentenceCase(String value) {
    if (value.isEmpty) return value;
    final trimmed = value.trim();
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }


  static String normalizePhone(String phone) {
    final clean = removeAllSpaces(phone).replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.startsWith('+62')) return clean;
    if (clean.startsWith('62'))  return '+$clean';
    if (clean.startsWith('0'))   return '+62${clean.substring(1)}';
    return '+62$clean';
  }

  static String formatPhoneDisplay(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    final local = digits.startsWith('62') ? '0${digits.substring(2)}' : digits;
    if (local.length < 9) return local;
    return '${local.substring(0, 4)}-${local.substring(4, 8)}-${local.substring(8)}';
  }


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


  static String truncate(String value, int maxLength, {String ellipsis = '...'}) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}$ellipsis';
  }


  static String toSlug(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');


  static bool isEmail(String value) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(value.trim());

  static bool isPhoneNumber(String value) =>
      RegExp(r'^(\+62|62|0)[0-9]{8,12}$').hasMatch(removeAllSpaces(value));

  static bool isNullOrEmpty(String? value) =>
      value == null || value.trim().isEmpty;

  static bool isNotNullOrEmpty(String? value) => !isNullOrEmpty(value);


  static String initials(String name, {int maxChars = 2}) {
    final words = trimAll(name).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return words
        .take(maxChars)
        .map((w) => w[0].toUpperCase())
        .join();
  }


  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final masked = local.length <= 1 ? local : '${local[0]}***';
    return '$masked@${parts[1]}';
  }

  static String maskPhone(String phone) {
    final clean = removeAllSpaces(phone);
    if (clean.length < 7) return clean;
    return '${clean.substring(0, 4)}****${clean.substring(clean.length - 3)}';
  }
}
