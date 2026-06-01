import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';

class RolePickerScreen extends StatelessWidget {
  final bool isGoogleCompletion;

  const RolePickerScreen({super.key, this.isGoogleCompletion = false});

  void _showGoogleCompleteDialog(BuildContext context, String role) {
    final namaCtrl = TextEditingController();
    final noHpCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                role == 'porter'
                    ? 'Lengkapi Data Porter'
                    : 'Lengkapi Data Mahasiswa',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama lengkap',
                      hintText: 'Masukkan nama lengkap',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noHpCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor HP',
                      hintText: '08xxxxxxxxxx',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final nama = namaCtrl.text.trim();
                          final noHp = noHpCtrl.text.trim();

                          if (nama.isEmpty || noHp.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nama dan nomor HP wajib diisi.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => loading = true);

                          final auth = context.read<AuthProvider>();

                          final result = await auth.completeGoogleProfile(
                            role: role,
                            nama: nama,
                            noHp: noHp,
                          );

                          if (!context.mounted) return;

                          Navigator.pop(dialogContext);

                          result.when(
                            success: (savedRole) {
                              if (savedRole == 'porter') {
                                context.go('/porter/home');
                              } else {
                                context.go('/user/home');
                              }
                            },
                            failure: (error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error.message),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            },
                          );
                        },
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = isGoogleCompletion
        ? 'Lengkapi Akun Google'
        : 'Kamu mau daftar sebagai apa?';

    final subtitle = isGoogleCompletion
        ? 'Pilih peran kamu terlebih dahulu untuk melanjutkan'
        : 'Pilih peran kamu di Go-Dah';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isGoogleCompletion ? 'Pilih Role' : 'Daftar Sebagai'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingScreen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            _RoleCard(
              icon: Icons.school_rounded,
              title: 'Mahasiswa',
              subtitle: 'Saya ingin menggunakan jasa angkut barang',
              color: AppColors.primary,
              onTap: () {
                if (isGoogleCompletion) {
                  _showGoogleCompleteDialog(context, 'user');
                } else {
                  context.push('/register/user');
                }
              },
            ),

            const SizedBox(height: 16),

            _RoleCard(
              icon: Icons.directions_run_rounded,
              title: 'Porter',
              subtitle: 'Saya ingin menjadi porter dan menerima pesanan',
              color: AppColors.accent700,
              onTap: () {
                if (isGoogleCompletion) {
                  _showGoogleCompleteDialog(context, 'porter');
                } else {
                  context.push('/register/porter');
                }
              },
            ),

            const Spacer(),

            if (!isGoogleCompletion)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Sudah punya akun? ', style: AppTextStyles.bodyMd),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text('Masuk', style: AppTextStyles.link),
                  ),
                ],
              )
            else
              TextButton(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                child: const Text('Batal dan logout'),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.grey200),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.h4),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.grey500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.grey400,
            ),
          ],
        ),
      ),
    );
  }
}
