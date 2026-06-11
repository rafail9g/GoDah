import '../constants/app_strings.dart';
import 'string_utils.dart';

abstract final class Validators {
  static String? required(String? value) {
    if (StringUtils.isNullOrEmpty(value)) return AppStrings.validRequired;
    return null;
  }

  static String? email(String? value) {
    final r = required(value);
    if (r != null) return r;
    if (!StringUtils.isEmail(value!)) return AppStrings.validEmail;
    return null;
  }

  static String? phone(String? value) {
    final r = required(value);
    if (r != null) return r;
    if (!StringUtils.isPhoneNumber(value!)) return AppStrings.validPhone;
    return null;
  }

  static String? password(String? value) {
    final r = required(value);
    if (r != null) return r;
    if (value!.length < 8) return AppStrings.validPasswordMin;
    return null;
  }


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
