import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../widgets/auth_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ResetPasswordScreen({super.key, this.initialEmail});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailCtrl.text.trim(),
        token: _tokenCtrl.text.trim(),
        type: OtpType.recovery,
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordCtrl.text),
      );
      await _markPasswordManaged(_emailCtrl.text.trim());
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata sandi berhasil diperbarui. Silakan masuk lagi.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui kata sandi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markPasswordManaged(String email) async {
    final supabase = Supabase.instance.client;

    await supabase
        .from('users')
        .update({'password_hash': 'supabase_managed'})
        .eq('email', email);

    try {
      await supabase
          .from('porters')
          .update({'password_hash': 'supabase_managed'})
          .eq('email', email);
    } on PostgrestException catch (e) {
      if (e.code != '42703' && !e.message.contains('password_hash')) {
        rethrow;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reset kata sandi'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Masukkan token email',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.grey900,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cek email dari Supabase, lalu masukkan token dan kata sandi baru.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey600),
          ),
          const SizedBox(height: 24),
          AuthTextField(
            controller: _emailCtrl,
            label: AppStrings.email,
            hint: 'contoh@email.com',
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _tokenCtrl,
            label: 'Token',
            hint: 'Masukkan token dari email',
            keyboardType: TextInputType.number,
            validator: Validators.required,
            prefixIcon: Icons.pin_outlined,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _passwordCtrl,
            label: AppStrings.password,
            hint: 'Masukkan kata sandi baru',
            obscureText: _obscurePassword,
            validator: Validators.password,
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.grey400,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _confirmCtrl,
            label: 'Konfirmasi kata sandi',
            hint: 'Ulangi kata sandi baru',
            obscureText: _obscureConfirm,
            validator: (value) {
              final required = Validators.required(value);
              if (required != null) return required;
              if (value != _passwordCtrl.text) {
                return AppStrings.validPasswordMatch;
              }
              return null;
            },
            prefixIcon: Icons.lock_reset_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.grey400,
              ),
              onPressed: () {
                setState(() => _obscureConfirm = !_obscureConfirm);
              },
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _savePassword,
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
                : const Text('Simpan kata sandi'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : () => context.go('/login'),
            child: const Text('Kembali ke Login'),
          ),
        ],
      ),
    );
  }
}
