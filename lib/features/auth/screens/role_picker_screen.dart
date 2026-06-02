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
        title: Text(
          isGoogleCompletion ? 'Pilih Peran' : 'Daftar Sebagai',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                title,
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.grey500,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Student Role Card
              _RoleCard(
                icon: Icons.school_rounded,
                title: 'Mahasiswa (User)',
                subtitle: 'Pesan porter untuk angkut barang koper, kardus, atau belanjaan di sekitar kampus.',
                color: const Color(0xFF1E3C72),
                onTap: () {
                  if (isGoogleCompletion) {
                    _showGoogleCompleteDialog(context, 'user');
                  } else {
                    context.push('/register/user');
                  }
                },
              ),

              const SizedBox(height: 18),

              // Porter Role Card
              _RoleCard(
                icon: Icons.directions_run_rounded,
                title: 'Porter (Kurir)',
                subtitle: 'Mulai hasilkan uang dengan menerima pesanan angkut barang dari sesama mahasiswa.',
                color: const Color(0xFF4CAF82),
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
                    Text(
                      'Sudah punya akun? ',
                      style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey600),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(
                        'Masuk',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: const Color(0xFF1E3C72),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                  child: Text(
                    'Batal dan logout',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.h4.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.grey500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: color.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
