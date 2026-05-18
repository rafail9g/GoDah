/// Sealed class untuk merepresentasikan hasil operasi async.
/// Dipakai di semua layer (repository, provider, UI) agar error handling konsisten.
///
/// Contoh penggunaan:
/// ```dart
/// final result = await orderRepository.createOrder(data);
/// result.when(
///   success: (order) => navigateToTracking(order.id),
///   failure: (error) => showSnackBar(error.message),
/// );
/// ```
sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
    Success<T>(data: final d) => d,
    Failure<T>() => null,
  };

  AppError? get errorOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(error: final e) => e,
  };

  /// Pattern matching untuk kedua kondisi.
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) => switch (this) {
    Success<T>(data: final d) => success(d),
    Failure<T>(error: final e) => failure(e),
  };

  /// Transformasi data jika sukses.
  AppResult<R> map<R>(R Function(T data) transform) => switch (this) {
    Success<T>(data: final d) => Success(transform(d)),
    Failure<T>(error: final e) => Failure(e),
  };
}

final class Success<T> extends AppResult<T> {
  final T data;
  const Success(this.data);

  @override
  String toString() => 'Success($data)';
}

final class Failure<T> extends AppResult<T> {
  final AppError error;
  const Failure(this.error);

  @override
  String toString() => 'Failure(${error.message})';
}

// ── AppError ────────────────────────────────────────────────────────────────

/// Representasi error yang bisa ditampilkan ke user.
class AppError {
  final String message;
  final String? code;
  final dynamic originalError;
  final AppErrorType type;

  const AppError({
    required this.message,
    this.code,
    this.originalError,
    this.type = AppErrorType.unknown,
  });

  // Factory constructors untuk error umum
  factory AppError.network() => const AppError(
    message: 'Koneksi bermasalah. Periksa internet kamu.',
    type: AppErrorType.network,
  );

  factory AppError.unauthorized() => const AppError(
    message: 'Sesi habis. Silakan login ulang.',
    type: AppErrorType.unauthorized,
  );

  factory AppError.notFound(String resource) => AppError(
    message: '$resource tidak ditemukan.',
    type: AppErrorType.notFound,
  );

  factory AppError.server() => const AppError(
    message: 'Server sedang bermasalah. Coba beberapa saat lagi.',
    type: AppErrorType.server,
  );

  factory AppError.validation(String message) =>
      AppError(message: message, type: AppErrorType.validation);

  factory AppError.fromException(Object e) => AppError(
    message: 'Terjadi kesalahan. Coba lagi.',
    originalError: e,
    type: AppErrorType.unknown,
  );

  @override
  String toString() => 'AppError($type: $message)';
}

enum AppErrorType {
  network,
  unauthorized,
  notFound,
  server,
  validation,
  unknown,
}
