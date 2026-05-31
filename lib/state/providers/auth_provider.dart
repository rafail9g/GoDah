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
    notifyListeners();

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

  // ── _loadProfile: retry 3x saja, jeda 1 detik ────────────────────
  // Cukup untuk nunggu trigger Supabase, tidak spam request
  Future<void> _loadProfile(String uid) async {
    for (int attempt = 0; attempt < 3; attempt++) {
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
          return;
        }

        // Belum ada → tunggu trigger Supabase
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (_) {
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  // ── Register User ─────────────────────────────────────────────────
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

      // Tunggu trigger selesai (3x retry, 1 detik jeda)
      await _loadProfile(res.user!.id);

      // Fallback: insert manual kalau trigger belum jalan
      if (_currentUser == null) {
        await _supabase.from('users').upsert({
          'id': res.user!.id,
          'nama': nama,
          'email': email,
          'no_hp': noHp,
          'password_hash': 'supabase_managed',
          if (alamat != null && alamat.isNotEmpty) 'alamat': alamat,
        });
        // Satu kali load lagi setelah insert manual
        await _loadProfile(res.user!.id);
      } else if (alamat != null && alamat.isNotEmpty) {
        // Update alamat kalau trigger sudah isi row tapi belum ada alamat
        await _supabase
            .from('users')
            .update({'alamat': alamat})
            .eq('id', res.user!.id);
      }

      if (_currentUser == null) {
        return Failure(
          AppError(message: 'Gagal memuat profil. Coba login ulang.'),
        );
      }
      return Success(_currentUser!);
    } on AuthException catch (e) {
      return Failure(AppError(message: _translateAuthError(e.message)));
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

  // ── Register Porter ───────────────────────────────────────────────
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

      // Tunggu trigger selesai
      await _loadProfile(res.user!.id);

      // Fallback: insert manual
      if (_currentPorter == null) {
        await _supabase.from('porters').upsert({
          'id': res.user!.id,
          'nama': nama,
          'email': email,
          'no_hp': noHp,
        });
        await _loadProfile(res.user!.id);
      }

      if (_currentPorter == null) {
        return Failure(
          AppError(message: 'Gagal memuat profil. Coba login ulang.'),
        );
      }
      return Success(_currentPorter!);
    } on AuthException catch (e) {
      return Failure(AppError(message: _translateAuthError(e.message)));
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

  // ── Login User/Porter ─────────────────────────────────────────────
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

      if (_role == null) {
        return Failure(
          AppError(message: 'Akun tidak ditemukan. Hubungi admin.'),
        );
      }

      return Success(_role!);
    } on AuthException catch (e) {
      return Failure(AppError(message: _translateAuthError(e.message)));
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

  // ── Login Admin ───────────────────────────────────────────────────
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

  // ── Logout ────────────────────────────────────────────────────────
  Future<void> logout() async {
    if (_currentAdmin != null) {
      _currentAdmin = null;
      notifyListeners();
      return;
    }
    _currentUser = null;
    _currentPorter = null;
    _role = null;
    notifyListeners();
    await _supabase.auth.signOut();
  }

  // ── Reload Porter Profile ─────────────────────────────────────────
  Future<void> reloadPorterProfile() async {
    if (_currentPorter == null) return;
    await _loadProfile(_currentPorter!.id);
    notifyListeners();
  }

  // ── Translate Auth Error ──────────────────────────────────────────
  String _translateAuthError(String msg) {
    if (msg.contains('already registered') ||
        msg.contains('already exists') ||
        msg.contains('User already registered')) {
      return 'Email sudah terdaftar. Silakan login.';
    }
    if (msg.contains('Invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Email atau password salah.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox kamu.';
    }
    if (msg.contains('Password should be')) {
      return 'Password minimal 8 karakter.';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Terlalu banyak percobaan. Tunggu 1 jam lalu coba lagi.';
    }
    return msg;
  }
}
