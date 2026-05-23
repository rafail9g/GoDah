import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../models/porter_model.dart';
import '../models/admin_model.dart';
import '../../core/utils/app_result.dart';

final _supabase = Supabase.instance.client;

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  PorterModel? _currentPorter;
  AdminModel? _currentAdmin;
  bool _isLoading = true;
  String? _role;

  UserModel? get currentUser => _currentUser;
  PorterModel? get currentPorter => _currentPorter;
  AdminModel? get currentAdmin => _currentAdmin;
  bool get isLoading => _isLoading;
  String? get role => _role;

  bool get isLoggedIn => _currentUser != null || _currentPorter != null;
  bool get isAdminLoggedIn => _currentAdmin != null;
  bool get isPorterVerified => _currentPorter?.statusVerifikasi == 'disetujui';

  // ── Init ─────────────────────────────────────────────────────────
  // FIX: isLoading harus false setelah init, bukan stuck di splash
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        await _loadProfile(session.user.id);
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners(); // <-- ini yang bikin router redirect dari splash

    _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn && data.session != null) {
        _isLoading = true;
        notifyListeners();
        await _loadProfile(data.session!.user.id);
        _isLoading = false;
        notifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _currentPorter = null;
        _role = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfile(String uid) async {
    try {
      final userRes = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (userRes != null) {
        _currentUser = UserModel.fromJson(userRes);
        _currentPorter = null;
        _role = 'user';
        return;
      }

      final porterRes = await _supabase
          .from('porters')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (porterRes != null) {
        _currentPorter = PorterModel.fromJson(porterRes);
        _currentUser = null;
        _role = 'porter';
      }
    } catch (_) {}
  }

  Future<AppResult<UserModel>> registerUser({
    required String nama,
    required String email,
    required String password,
    required String noHp,
    String? alamat,
  }) async {
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': 'user', 'nama': nama, 'no_hp': noHp},
      );

      if (res.user == null) {
        return Failure(AppError(message: 'Registrasi gagal, coba lagi.'));
      }

      if (alamat != null && alamat.isNotEmpty) {
        await _supabase
            .from('users')
            .update({'alamat': alamat})
            .eq('id', res.user!.id);
      }

      await _loadProfile(res.user!.id);
      if (_currentUser == null) {
        return Failure(AppError(message: 'Gagal memuat profil.'));
      }
      return Success(_currentUser!);
    } on AuthException catch (e) {
      return Failure(AppError(message: _translateAuthError(e.message)));
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

  Future<AppResult<PorterModel>> registerPorter({
    required String nama,
    required String email,
    required String password,
    required String noHp,
  }) async {
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': 'porter', 'nama': nama, 'no_hp': noHp},
      );

      if (res.user == null) {
        return Failure(AppError(message: 'Registrasi gagal, coba lagi.'));
      }

      await _loadProfile(res.user!.id);
      if (_currentPorter == null) {
        return Failure(AppError(message: 'Gagal memuat profil porter.'));
      }
      return Success(_currentPorter!);
    } on AuthException catch (e) {
      return Failure(AppError(message: _translateAuthError(e.message)));
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

  Future<AppResult<String>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        return Failure(AppError(message: 'Login gagal.'));
      }

      await _loadProfile(res.user!.id);
      return Success(_role ?? 'user');
    } on AuthException catch (e) {
      return Failure(AppError(message: _translateAuthError(e.message)));
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

  Future<AppResult<AdminModel>> loginAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase
          .from('admins')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (res == null || res['password_hash'] != password) {
        return Failure(AppError(message: 'Email atau password salah.'));
      }

      _currentAdmin = AdminModel.fromJson(res);
      notifyListeners();
      return Success(_currentAdmin!);
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

  Future<void> logout() async {
    if (_currentAdmin != null) {
      _currentAdmin = null;
      notifyListeners();
      return;
    }
    await _supabase.auth.signOut();
  }

  Future<void> reloadPorterProfile() async {
    if (_currentPorter == null) return;
    await _loadProfile(_currentPorter!.id);
    notifyListeners();
  }

  String _translateAuthError(String msg) {
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'Email sudah terdaftar. Silakan login.';
    }
    if (msg.contains('Invalid login credentials')) {
      return 'Email atau password salah.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox kamu.';
    }
    if (msg.contains('Password should be')) {
      return 'Password minimal 6 karakter.';
    }
    return msg;
  }
}
