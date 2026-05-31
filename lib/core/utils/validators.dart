import '../constants/app_strings.dart';
import 'string_utils.dart';

/// Fungsi validasi siap pakai untuk TextFormField.
/// Semua fungsi mengembalikan String? (null = valid, string = pesan error).
abstract final class Validators {
  // ── Required ───────────────────────────────────────────────────────
  static String? required(String? value) {
    if (StringUtils.isNullOrEmpty(value)) return AppStrings.validRequired;
    return null;
  }

  // ── Email ──────────────────────────────────────────────────────────
  static String? email(String? value) {
    final r = required(value);
    if (r != null) return r;
    if (!StringUtils.isEmail(value!)) return AppStrings.validEmail;
    return null;
  }

  // ── Phone ──────────────────────────────────────────────────────────
  static String? phone(String? value) {
    final r = required(value);
    if (r != null) return r;
    if (!StringUtils.isPhoneNumber(value!)) return AppStrings.validPhone;
    return null;
  }

  // ── Password ───────────────────────────────────────────────────────
  static String? password(String? value) {
    final r = required(value);
    if (r != null) return r;
    if (value!.length < 8) return AppStrings.validPasswordMin;
    return null;
  }

  // ── CATATAN: confirmPassword TIDAK ada di sini ──────────────────────
  // Jangan pakai closure untuk confirm password karena Flutter Form
  // men-cache validator saat build. Nilai yang di-capture adalah nilai
  // kosong pada saat build, bukan nilai terbaru saat submit.
  //
  // Cara benar: buat method instance di dalam State:
  //
  //   String? _validateConfirmPass(String? value) {
  //     if (value == null || value.isEmpty) return AppStrings.validRequired;
  //     if (value != _passCtrl.text) return AppStrings.validPasswordMatch;
  //     return null;
  //   }
  //
  // Lalu gunakan: validator: _validateConfirmPass
  // ──────────────────────────────────────────────────────────────────

  // ── Min/Max length ─────────────────────────────────────────────────
  static String? Function(String?) minLength(int min) {
    return (String? value) {
      final r = required(value);
      if (r != null) return r;
      if (value!.length < min) return 'Minimal $min karakter';
      return null;
    };
  }

  static String? Function(String?) maxLength(int max) {
    return (String? value) {
      if (value == null) return null;
      if (value.length > max) return 'Maksimal $max karakter';
      return null;
    };
  }

  // ── Numeric ────────────────────────────────────────────────────────
  static String? numeric(String? value) {
    final r = required(value);
    if (r != null) return r;
    if (double.tryParse(value!) == null) return 'Harus berupa angka';
    return null;
  }

  static String? Function(String?) min(double minVal) {
    return (String? value) {
      final numCheck = numeric(value);
      if (numCheck != null) return numCheck;
      final n = double.parse(value!);
      if (n < minVal) return 'Nilai minimal $minVal';
      return null;
    };
  }

  // ── Compose: gabungkan beberapa validator ──────────────────────────
  static String? Function(String?) compose(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final v in validators) {
        final result = v(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
