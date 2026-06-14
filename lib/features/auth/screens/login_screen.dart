import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/brand_video_logo.dart';
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
  String? _errorMessage;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final message = context.read<AuthProvider>().consumePendingAuthMessage();
    if (message == null) return;
    _errorMessage = _loginErrorMessage(message);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    final adminResult = await auth.loginAdmin(email: email, password: password);
    if (!mounted) return;

    if (adminResult.isSuccess) {
      setState(() => _loading = false);
      context.go('/admin/home');
      return;
    }

    final userResult = await auth.login(email: email, password: password);
    if (!mounted) return;
    setState(() => _loading = false);

    userResult.when(
      success: (_) {},
      failure: (error) {
        setState(() => _errorMessage = _loginErrorMessage(error.message));
      },
    );
  }

  void _clearError() {
    if (_errorMessage == null) return;
    setState(() => _errorMessage = null);
  }

  String _loginErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('diblokir') || lower.contains('dinonaktifkan')) {
      return message;
    }

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('email atau password salah')) {
      return 'Email atau password anda salah.';
    }

    return message;
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _googleLoading = true);

    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _googleLoading = false);
        return;
      }

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

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
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

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final formKey = GlobalKey<FormState>();
    var sending = false;

    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: !sending,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Lupa kata sandi'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masukkan email akun GoDah kamu. Token reset akan dikirim lewat email.',
                    style: AppTextStyles.bodyMd,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    decoration: const InputDecoration(
                      labelText: AppStrings.email,
                      hintText: 'contoh@email.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: sending
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setDialogState(() => sending = true);
                        try {
                          final email = emailCtrl.text.trim();
                          final accountExists = await _accountExists(email);
                          if (!accountExists) {
                            if (!ctx.mounted) return;
                            setDialogState(() => sending = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Email akun tidak ditemukan.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          await Supabase.instance.client.auth
                              .resetPasswordForEmail(email);

                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (!ctx.mounted) return;
                          setDialogState(() => sending = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Gagal mengirim token reset: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Kirim Token'),
              ),
            ],
          );
        },
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 350), emailCtrl.dispose);

    if (sent == true && mounted) {
      final email = Uri.encodeComponent(emailCtrl.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token reset kata sandi sudah dikirim.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.push('/reset-password?email=$email');
    }
  }

  Future<bool> _accountExists(String email) async {
    final supabase = Supabase.instance.client;

    final user = await supabase
        .from('users')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    if (user != null) return true;

    final porter = await supabase
        .from('porters')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    return porter != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                  child: Column(
                    children: [
                      const BrandVideoLogo(
                        asset: 'assets/branding/order_logo.mp4',
                        width: 72,
                        height: 72,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppStrings.appName,
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.appTagline,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.white.withOpacity(0.82),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.68,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Selamat datang',
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.grey900,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Masuk untuk lanjut pakai GoDah.',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.grey600,
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.error.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: AppColors.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: AppTextStyles.bodySm.copyWith(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            AuthTextField(
                              controller: _emailCtrl,
                              label: AppStrings.email,
                              hint: 'contoh@email.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                              prefixIcon: Icons.email_outlined,
                              onTap: _clearError,
                              onChanged: (_) => _clearError(),
                            ),
                            const SizedBox(height: 16),
                            AuthTextField(
                              controller: _passCtrl,
                              label: AppStrings.password,
                              hint: 'Masukkan password',
                              obscureText: _obscure,
                              validator: Validators.required,
                              prefixIcon: Icons.lock_outline_rounded,
                              onTap: _clearError,
                              onChanged: (_) => _clearError(),
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
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  AppStrings.forgotPassword,
                                  style: AppTextStyles.labelMd.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                minimumSize: const Size.fromHeight(54),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
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
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(
                                  child: Divider(color: AppColors.grey300),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    'atau',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.grey500,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: Divider(color: AppColors.grey300),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton(
                              onPressed: _googleLoading
                                  ? null
                                  : _loginWithGoogle,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.grey800,
                                backgroundColor: AppColors.white,
                                minimumSize: const Size.fromHeight(54),
                                side: const BorderSide(
                                  color: AppColors.grey300,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const _GoogleLogo(size: 20),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Masuk dengan Google',
                                          style: AppTextStyles.buttonMd
                                              .copyWith(
                                                color: AppColors.grey800,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 28),
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
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  final double size;

  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.18;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect.deflate(strokeWidth / 2), -0.08, 1.45, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect.deflate(strokeWidth / 2), 1.37, 1.28, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect.deflate(strokeWidth / 2), 2.65, 1.16, false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect.deflate(strokeWidth / 2), 3.81, 1.46, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final centerY = size.height * 0.52;
    canvas.drawLine(
      Offset(size.width * 0.52, centerY),
      Offset(size.width * 0.94, centerY),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
