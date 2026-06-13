import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/fcm_service.dart';
import '../models/user_model.dart';
import '../models/porter_model.dart';
import '../models/admin_model.dart';
import '../../core/utils/app_result.dart';

final _supabase = Supabase.instance.client;

class AuthProvider extends ChangeNotifier {
  static const _adminSessionKey = 'godah_admin_id';
  static const _minimumSplashDuration = Duration(seconds: 3);

  UserModel? _currentUser;
  PorterModel? _currentPorter;
  AdminModel? _currentAdmin;
  bool _isLoading = true;
  String? _role;
  String? _lastAccountBlockMessage;
  String? _lastProfileLoadErrorMessage;

  bool _isManualLogin = false;

  UserModel? get currentUser => _currentUser;
  PorterModel? get currentPorter => _currentPorter;
  AdminModel? get currentAdmin => _currentAdmin;
  bool get isLoading => _isLoading;
  String? get role => _role;

  bool get isLoggedIn => _currentUser != null || _currentPorter != null;
  bool get isAdminLoggedIn => _currentAdmin != null;
  bool get isPorterVerified => _currentPorter?.statusVerifikasi == 'disetujui';

  bool get hasSupabaseSession => _supabase.auth.currentUser != null;

  bool get needsRoleSelection =>
      hasSupabaseSession &&
      _currentUser == null &&
      _currentPorter == null &&
      _currentAdmin == null &&
      _role == null;

  Future<void> init() async {
    final splashStartedAt = DateTime.now();
    _isLoading = true;
    notifyListeners();

    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        await _loadProfile(session.user.id);
      } else {
        await _restoreAdminSession();
      }
    } catch (_) {}

    final splashElapsed = DateTime.now().difference(splashStartedAt);
    if (splashElapsed < _minimumSplashDuration) {
      await Future.delayed(_minimumSplashDuration - splashElapsed);
    }

    _isLoading = false;
    notifyListeners();

    _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;

      if (event == AuthChangeEvent.signedIn && data.session != null) {
        if (_isManualLogin) return;

        _isLoading = true;
        notifyListeners();

        await _loadProfile(data.session!.user.id);

        _isLoading = false;
        notifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _currentPorter = null;
        _currentAdmin = null;
        _role = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfile(String uid) async {
    _currentUser = null;
    _currentPorter = null;
    _currentAdmin = null;
    _role = null;
    _lastAccountBlockMessage = null;
    _lastProfileLoadErrorMessage = null;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final userRes = await _supabase
            .from('users')
            .select()
            .eq('id', uid)
            .maybeSingle();

        if (userRes != null) {
          final user = UserModel.fromJson(userRes);
          if (_isRestrictedStatus(user.status)) {
            _lastAccountBlockMessage = _blockedAccountMessage(
              'user',
              user.status,
            );
            await _supabase.auth.signOut();
            return;
          }

          _currentUser = user;
          _currentPorter = null;
          _role = 'user';
          unawaited(FcmService.instance.saveUserToken(_currentUser!.id));
          return;
        }

        final porterRes = await _supabase
            .from('porters')
            .select()
            .eq('id', uid)
            .maybeSingle();

        if (porterRes != null) {
          final porter = PorterModel.fromJson(porterRes);
          if (_isRestrictedStatus(porter.status)) {
            _lastAccountBlockMessage = _blockedAccountMessage(
              'porter',
              porter.status,
            );
            await _supabase.auth.signOut();
            return;
          }

          _currentPorter = porter;
          _currentUser = null;
          _role = 'porter';
          unawaited(FcmService.instance.savePorterToken(_currentPorter!.id));
          return;
        }

        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        _lastProfileLoadErrorMessage = 'Gagal memuat profil akun: $e';
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  Future<void> _restoreAdminSession() async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString(_adminSessionKey);
    if (adminId == null || adminId.isEmpty) return;

    try {
      final res = await _supabase
          .from('admins')
          .select()
          .eq('id', adminId)
          .maybeSingle();
      if (res == null) {
        await prefs.remove(_adminSessionKey);
        return;
      }

      _currentAdmin = AdminModel.fromJson(res);
      _currentUser = null;
      _currentPorter = null;
      _role = 'admin';
      unawaited(FcmService.instance.saveAdminToken(_currentAdmin!.id));
    } catch (_) {}
  }

  Future<void> refreshCurrentSession() async {
    final session = _supabase.auth.currentSession;

    if (session != null) {
      await _loadProfile(session.user.id);
      notifyListeners();
      return;
    }

    if (_currentAdmin != null) {
      await _restoreAdminSession();
      notifyListeners();
    }
  }

  Future<AppResult<String>> completeGoogleProfile({
    required String role,
    required String nama,
    required String noHp,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;

      if (authUser == null) {
        return Failure(AppError(message: 'Session Google tidak ditemukan.'));
      }

      final email = authUser.email;

      if (email == null || email.isEmpty) {
        return Failure(AppError(message: 'Email Google tidak ditemukan.'));
      }

      if (role == 'porter') {
        await _supabase.from('porters').upsert({
          'id': authUser.id,
          'nama': nama,
          'email': email,
          'no_hp': noHp,
        });

        await _loadProfile(authUser.id);

        if (_lastAccountBlockMessage != null) {
          return Failure(AppError(message: _lastAccountBlockMessage!));
        }

        if (_currentPorter == null) {
          return Failure(AppError(message: 'Gagal membuat profil porter.'));
        }

        notifyListeners();
        return Success('porter');
      }

      await _supabase.from('users').upsert({
        'id': authUser.id,
        'nama': nama,
        'email': email,
        'no_hp': noHp,
        'password_hash': 'google_oauth',
      });

      await _loadProfile(authUser.id);

      if (_lastAccountBlockMessage != null) {
        return Failure(AppError(message: _lastAccountBlockMessage!));
      }

      if (_currentUser == null) {
        return Failure(AppError(message: 'Gagal membuat profil mahasiswa.'));
      }

      notifyListeners();
      return Success('user');
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

  Future<AppResult<UserModel>> registerUser({
    required String nama,
    required String email,
    required String password,
    required String noHp,
    String? alamat,
  }) async {
    try {
      _isManualLogin = true;

      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': 'user', 'nama': nama, 'no_hp': noHp},
      );

      if (res.user == null) {
        _isManualLogin = false;
        return Failure(AppError(message: 'Registrasi gagal, coba lagi.'));
      }

      await _loadProfile(res.user!.id);

      if (_currentUser == null) {
        await _supabase.from('users').upsert({
          'id': res.user!.id,
          'nama': nama,
          'email': email,
          'no_hp': noHp,
          'password_hash': 'supabase_managed',
          if (alamat != null && alamat.isNotEmpty) 'alamat': alamat,
        });

        await _loadProfile(res.user!.id);
      } else if (alamat != null && alamat.isNotEmpty) {
        await _supabase
            .from('users')
            .update({'alamat': alamat})
            .eq('id', res.user!.id);
      }

      _isManualLogin = false;

      if (_currentUser == null) {
        return Failure(
          AppError(message: 'Gagal memuat profil. Coba login ulang.'),
        );
      }

      notifyListeners();
      return Success(_currentUser!);
    } on AuthException catch (e) {
      _isManualLogin = false;
      return Failure(AppError(message: _translateAuthError(e.message)));
    } catch (e) {
      _isManualLogin = false;
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
      _isManualLogin = true;

      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': 'porter', 'nama': nama, 'no_hp': noHp},
      );

      if (res.user == null) {
        _isManualLogin = false;
        return Failure(AppError(message: 'Registrasi gagal, coba lagi.'));
      }

      await _loadProfile(res.user!.id);

      if (_currentPorter == null) {
        await _supabase.from('porters').upsert({
          'id': res.user!.id,
          'nama': nama,
          'email': email,
          'no_hp': noHp,
        });

        await _loadProfile(res.user!.id);
      }

      _isManualLogin = false;

      if (_currentPorter == null) {
        return Failure(
          AppError(message: 'Gagal memuat profil. Coba login ulang.'),
        );
      }

      notifyListeners();
      return Success(_currentPorter!);
    } on AuthException catch (e) {
      _isManualLogin = false;
      return Failure(AppError(message: _translateAuthError(e.message)));
    } catch (e) {
      _isManualLogin = false;
      return Failure(AppError.fromException(e));
    }
  }

  Future<AppResult<String>> login({
    required String email,
    required String password,
  }) async {
    try {
      _isManualLogin = true;

      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        _isManualLogin = false;
        return Failure(AppError(message: 'Login gagal.'));
      }

      await _loadProfile(res.user!.id);

      _isManualLogin = false;

      if (_lastAccountBlockMessage != null) {
        return Failure(AppError(message: _lastAccountBlockMessage!));
      }

      if (_role == null) {
        return Failure(
          AppError(
            message:
                _lastProfileLoadErrorMessage ??
                'Akun tidak ditemukan. Hubungi admin.',
          ),
        );
      }

      notifyListeners();
      return Success(_role!);
    } on AuthException catch (e) {
      _isManualLogin = false;
      return Failure(AppError(message: _translateAuthError(e.message)));
    } catch (e) {
      _isManualLogin = false;
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
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();

      if (res == null) {
        return Failure(AppError(message: 'Email atau password salah.'));
      }

      final storedPassword = res['password_hash'] as String? ?? '';

      if (storedPassword != password) {
        return Failure(AppError(message: 'Email atau password salah.'));
      }

      _currentAdmin = AdminModel.fromJson(res);
      _role = 'admin';
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_adminSessionKey, _currentAdmin!.id);
      unawaited(FcmService.instance.saveAdminToken(_currentAdmin!.id));

      return Success(_currentAdmin!);
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.message.contains('permission')) {
        return Failure(
          AppError(
            message: 'Konfigurasi server bermasalah. Hubungi developer.',
          ),
        );
      }

      return Failure(AppError(message: 'Terjadi kesalahan: ${e.message}'));
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    if (_currentAdmin != null) {
      await FcmService.instance.clearAdminToken(_currentAdmin!.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_adminSessionKey);
      _currentAdmin = null;
      _role = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    final userId = _currentUser?.id;
    final porterId = _currentPorter?.id;

    if (userId != null) await FcmService.instance.clearUserToken(userId);
    if (porterId != null) await FcmService.instance.clearPorterToken(porterId);
    await _supabase.auth.signOut();

    _currentUser = null;
    _currentPorter = null;
    _role = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> reloadPorterProfile() async {
    if (_currentPorter == null) return;

    await _loadProfile(_currentPorter!.id);
    notifyListeners();
  }

  Future<void> reloadUserProfile() async {
    if (_currentUser == null) return;

    await _loadProfile(_currentUser!.id);
    notifyListeners();
  }

  bool _isRestrictedStatus(String status) =>
      status == 'nonaktif' || status == 'diblokir';

  String _blockedAccountMessage(String role, String status) {
    final roleLabel = role == 'porter' ? 'porter' : 'user';
    final statusLabel = status == 'diblokir' ? 'diblokir' : 'dinonaktifkan';
    return 'Akun $roleLabel sedang $statusLabel. Hubungi admin.';
  }

  Future<AppResult<void>> updateUserProfile({
    required String nama,
    required String noHp,
    String? alamat,
  }) async {
    final user = _currentUser;
    if (user == null) {
      return Failure(AppError(message: 'Profil user tidak ditemukan.'));
    }

    try {
      await _supabase
          .from('users')
          .update({
            'nama': nama.trim(),
            'no_hp': noHp.trim(),
            'alamat': alamat?.trim(),
          })
          .eq('id', user.id);

      await _loadProfile(user.id);
      notifyListeners();

      return const Success(null);
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

  Future<AppResult<void>> updatePorterProfile({
    required String nama,
    required String noHp,
  }) async {
    final porter = _currentPorter;
    if (porter == null) {
      return Failure(AppError(message: 'Profil porter tidak ditemukan.'));
    }

    try {
      await _supabase
          .from('porters')
          .update({'nama': nama.trim(), 'no_hp': noHp.trim()})
          .eq('id', porter.id);

      await _loadProfile(porter.id);
      notifyListeners();

      return const Success(null);
    } catch (e) {
      return Failure(AppError.fromException(e));
    }
  }

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
