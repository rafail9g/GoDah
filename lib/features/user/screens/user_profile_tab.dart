import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';

class UserProfileTab extends StatelessWidget {
  const UserProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profil Saya')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingScreen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar & nama
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary100,
                    child: Text(
                      user?.initials ?? 'U',
                      style: AppTextStyles.displayMd.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user?.nama ?? '-', style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '-',
                    style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppDimens.radiusRound),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_rounded, size: 14, color: AppColors.success),
                        const SizedBox(width: 5),
                        Text(
                          'Mahasiswa',
                          style: AppTextStyles.labelSm.copyWith(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info card
            _InfoCard(children: [
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'No. HP',
                value: user?.formattedPhone ?? '-',
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Alamat',
                value: user?.alamat ?? 'Belum diisi',
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.shield_outlined,
                label: 'Status Akun',
                value: user?.isActive == true ? 'Aktif' : 'Nonaktif',
                valueColor: user?.isActive == true ? AppColors.success : AppColors.error,
              ),
            ]),
            const SizedBox(height: 16),

            // Menu
            _InfoCard(children: [
              _MenuRow(
                icon: Icons.edit_outlined,
                label: 'Edit Profil',
                onTap: () {},
              ),
              const Divider(height: 1),
              _MenuRow(
                icon: Icons.lock_outline_rounded,
                label: 'Ganti Password',
                onTap: () {},
              ),
              const Divider(height: 1),
              _MenuRow(
                icon: Icons.help_outline_rounded,
                label: 'Bantuan & FAQ',
                onTap: () {},
              ),
              const Divider(height: 1),
              _MenuRow(
                icon: Icons.info_outline_rounded,
                label: 'Tentang Go-Dah',
                onTap: () {},
              ),
              const Divider(height: 1),
              _MenuRow(
                icon: Icons.logout_rounded,
                label: 'Keluar',
                color: AppColors.error,
                onTap: () async {
                  await auth.logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ]),
            const SizedBox(height: 24),

            // App version
            Text(
              'Go-Dah v1.0.0 • Jasa Angkut Barang Mahasiswa',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.labelLg),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMd.copyWith(
                color: valueColor ?? AppColors.grey600,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.grey800,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.labelLg.copyWith(color: color)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.grey400),
          ],
        ),
      ),
    );
  }
}
