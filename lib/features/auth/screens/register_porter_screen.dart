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

class RegisterPorterScreen extends StatefulWidget {
  const RegisterPorterScreen({super.key});

  @override
  State<RegisterPorterScreen> createState() => _RegisterPorterScreenState();
}

class _RegisterPorterScreenState extends State<RegisterPorterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noHpCtrl = TextEditingController();
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
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final result = await auth.registerPorter(
      nama: _namaCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      noHp: _noHpCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (_) => context.go('/porter/home'),
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
      appBar: AppBar(title: const Text('Daftar Porter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingScreen),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.info, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Setelah daftar, kamu perlu upload dokumen verifikasi '
                        'di halaman profil sebelum bisa menerima order.',
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('Daftar Sebagai Porter', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text(
                'Isi data diri kamu untuk bergabung sebagai porter',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey500),
              ),
              const SizedBox(height: 24),

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
                controller: _passCtrl,
                label: AppStrings.password,
                hint: 'Minimal 6 karakter',
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
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _confirmPassCtrl,
                label: 'Konfirmasi Password',
                hint: 'Ulangi password',
                obscureText: _obscureConfirm,
                prefixIcon: Icons.lock_outline_rounded,
                validator: Validators.confirmPassword(_passCtrl.text),
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
                  backgroundColor: AppColors.accent700,
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
                    : const Text('Daftar Sebagai Porter'),
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
