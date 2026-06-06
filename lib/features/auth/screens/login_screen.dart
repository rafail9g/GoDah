import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../state/providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '764544622115-l65mn9in1va4b6evie9kjjsdg78ns96b.apps.googleusercontent.com',
  );

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    // Coba login admin dulu
    final adminResult = await auth.loginAdmin(email: email, password: password);
    if (!mounted) return;

    if (adminResult.isSuccess) {
      setState(() => _loading = false);
      context.go('/admin/home');
      return;
    }

    // Login user/porter biasa
    final userResult = await auth.login(email: email, password: password);
    if (!mounted) return;
    setState(() => _loading = false);

    userResult.when(
      success: (_) {},
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _googleLoading = true);

    try {
      // Paksa sign out dulu agar user bisa pilih akun
      await _googleSignIn.signOut();

      // Tampilkan dialog pilih akun Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User menekan tombol back / cancel
        setState(() => _googleLoading = false);
        return;
      }

      // Ambil token autentikasi (google_sign_in ^6.x)
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception(
          'ID Token tidak ditemukan.\n'
          'Pastikan SHA-1 fingerprint sudah didaftarkan di Google Cloud Console.',
        );
      }

      // Kirim token ke Supabase
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Navigasi otomatis ditangani AuthProvider + GoRouter
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal login Google: $msg'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3C72),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Gradient Block
            Container(
              height: 250,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Box
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: Color(0xFF1E3C72),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.appName,
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.appTagline,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom White Card Form Sheet
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Selamat Datang Kembali',
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Login ke akun Go-Dah kamu',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.grey500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Card Form Wrapper
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          AuthTextField(
                            controller: _emailCtrl,
                            label: AppStrings.email,
                            hint: 'contoh@email.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                            prefixIcon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 20),
                          AuthTextField(
                            controller: _passCtrl,
                            label: AppStrings.password,
                            hint: 'Masukkan password',
                            obscureText: _obscure,
                            validator: Validators.required,
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.grey400,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                AppStrings.forgotPassword,
                                style: AppTextStyles.labelMd.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Login Button
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3C72),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Text(
                              AppStrings.login,
                              style: AppTextStyles.buttonLg.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Divider
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: AppColors.grey300),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'atau',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.grey400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: AppColors.grey300),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Google Login Button
                    OutlinedButton(
                      onPressed: _googleLoading ? null : _loginWithGoogle,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(
                          color: AppColors.grey300,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: AppColors.white,
                      ),
                      child: _googleLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                                  width: 20,
                                  height: 20,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.g_mobiledata_rounded,
                                    size: 24,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Masuk dengan Google',
                                  style: AppTextStyles.buttonMd.copyWith(
                                    color: AppColors.grey800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 32),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.noAccount,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.grey600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/register'),
                          child: Text(
                            ' Daftar',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: const Color(0xFF1E3C72),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
