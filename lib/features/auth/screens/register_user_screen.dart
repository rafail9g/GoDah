import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../state/providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noHpCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _noHpCtrl.dispose();
    _alamatCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // FIX: validator confirmPassword harus dibaca saat validasi, bukan saat build
  String? _validateConfirmPass(String? value) {
    if (value == null || value.isEmpty) return AppStrings.validRequired;
    if (value != _passCtrl.text) return AppStrings.validPasswordMatch;
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final result = await auth.registerUser(
      nama: _namaCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      noHp: _noHpCtrl.text.trim(),
      alamat: _alamatCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (_) => context.go('/user/home'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Daftar Mahasiswa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingScreen),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Buat Akun Baru', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text(
                'Isi data diri kamu untuk mulai menggunakan Go-Dah',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey500),
              ),
              const SizedBox(height: 28),

              AuthTextField(
                controller: _namaCtrl,
                label: 'Nama Lengkap',
                hint: 'Masukkan nama lengkap',
                prefixIcon: Icons.person_outline_rounded,
                validator: Validators.required,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _emailCtrl,
                label: AppStrings.email,
                hint: 'contoh@email.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _noHpCtrl,
                label: 'Nomor HP',
                hint: '08xxxxxxxxxx',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                validator: Validators.phone,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _alamatCtrl,
                label: 'Alamat (opsional)',
                hint: 'Contoh: Kos Melati, Jl. Kalimantan No. 12',
                prefixIcon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _passCtrl,
                label: AppStrings.password,
                hint: 'Minimal 8 karakter',
                obscureText: _obscurePass,
                prefixIcon: Icons.lock_outline_rounded,
                validator: Validators.password,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.grey400,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _confirmPassCtrl,
                label: 'Konfirmasi Password',
                hint: 'Ulangi password',
                obscureText: _obscureConfirm,
                prefixIcon: Icons.lock_outline_rounded,
                // FIX: pakai method lokal, bukan closure yang di-capture saat build
                validator: _validateConfirmPass,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.grey400,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppDimens.buttonHeightMd),
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
                    : const Text('Daftar Sekarang'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(AppStrings.hasAccount, style: AppTextStyles.bodyMd),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text(' Masuk', style: AppTextStyles.link),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
