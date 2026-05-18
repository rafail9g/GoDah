import 'package:flutter/foundation.dart';
import '../../core/utils/app_result.dart';

/// Enum status loading untuk setiap provider.
enum ViewState { idle, loading, success, error }

/// Base class untuk semua Provider di Go-Dah.
/// Sediakan setState, loading, error handling yang konsisten.
///
/// Contoh implementasi:
/// ```dart
/// class OrderProvider extends BaseProvider {
///   List<Order> _orders = [];
///   List<Order> get orders => _orders;
///
///   Future<void> fetchOrders() async {
///     await runAsync(() async {
///       final result = await _repository.getOrders();
///       return result.map((list) {
///         _orders = list;
///         return list;
///       });
///     });
///   }
/// }
/// ```
abstract class BaseProvider extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  AppError? _error;
  bool _disposed = false;

  ViewState get state => _state;
  AppError?  get error => _error;

  bool get isIdle    => _state == ViewState.idle;
  bool get isLoading => _state == ViewState.loading;
  bool get isSuccess => _state == ViewState.success;
  bool get isError   => _state == ViewState.error;
  bool get hasError  => _error != null;

  // ── State transitions ──────────────────────────────────────────────

  void setLoading() {
    _state = ViewState.loading;
    _error = null;
    _notify();
  }

  void setSuccess() {
    _state = ViewState.success;
    _error = null;
    _notify();
  }

  void setError(AppError error) {
    _state = ViewState.error;
    _error = error;
    _notify();
  }

  void setIdle() {
    _state = ViewState.idle;
    _error = null;
    _notify();
  }

  void clearError() {
    _error = null;
    if (_state == ViewState.error) _state = ViewState.idle;
    _notify();
  }

  // ── Run async with auto state management ──────────────────────────

  /// Jalankan operasi async, auto-set loading/success/error.
  Future<AppResult<T>> runAsync<T>(
    Future<AppResult<T>> Function() operation, {
    bool setLoadingState = true,
  }) async {
    if (setLoadingState) setLoading();

    try {
      final result = await operation();
      result.when(
        success: (_) => setSuccess(),
        failure: setError,
      );
      return result;
    } catch (e) {
      final error = AppError.fromException(e);
      setError(error);
      return Failure(error);
    }
  }

  // ── Safe notify ───────────────────────────────────────────────────

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Update state tanpa mengubah ViewState utama.
  void update(VoidCallback fn) {
    fn();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
