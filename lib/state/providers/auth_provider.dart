import '../models/user_model.dart';
import 'base_provider.dart';
import '../../core/utils/app_result.dart';

/// Provider untuk autentikasi user (login, logout, session).
/// Daftarkan di MultiProvider pada main.dart.
class AuthProvider extends BaseProvider {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // ── Login ──────────────────────────────────────────────────────────

  Future<AppResult<UserModel>> login({
    required String email,
    required String password,
  }) async {
    return runAsync(() async {
      // TODO: Ganti dengan panggilan ke Supabase
      // final response = await supabase.auth.signInWithPassword(
      //   email: email, password: password,
      // );
      // _currentUser = UserModel.fromJson(response.user!.toJson());

      // Simulasi sukses untuk development
      await Future.delayed(const Duration(seconds: 1));
      final fakeUser = UserModel(
        id: 'user-123',
        nama: 'Budi Mahasiswa',
        email: email,
        noHp: '08123456789',
        status: 'aktif',
      );
      _currentUser = fakeUser;
      return Success(fakeUser);
    });
  }

  // ── Logout ─────────────────────────────────────────────────────────

  Future<void> logout() async {
    setLoading();
    // TODO: await supabase.auth.signOut();
    _currentUser = null;
    setIdle();
  }

  // ── Restore session ────────────────────────────────────────────────

  Future<void> restoreSession() async {
    // TODO: cek token tersimpan dan restore session Supabase
    // final session = supabase.auth.currentSession;
    // if (session != null) { ... }
    setIdle();
  }
}
