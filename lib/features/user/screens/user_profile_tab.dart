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
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Profile Block
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: AppColors.primary100,
                      child: Text(
                        user?.initials ?? 'U',
                        style: AppTextStyles.displayMd.copyWith(
                          color: const Color(0xFF1E3C72),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.nama ?? '-',
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '-',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_rounded, size: 14, color: AppColors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Mahasiswa',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'INFORMASI AKUN',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.grey500,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  _InfoCard(children: [
                    _InfoRow(
                      icon: Icons.phone_android_rounded,
                      label: 'No. HP',
                      value: user?.formattedPhone ?? '-',
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      icon: Icons.location_on_rounded,
                      label: 'Alamat Kos/Gedung',
                      value: user?.alamat ?? 'Belum diisi',
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      icon: Icons.shield_rounded,
                      label: 'Status Akun',
                      value: user?.isActive == true ? 'Aktif' : 'Nonaktif',
                      valueColor: user?.isActive == true ? AppColors.success : AppColors.error,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'PENGATURAN',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.grey500,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  _InfoCard(children: [
                    _MenuRow(
                      icon: Icons.edit_rounded,
                      label: 'Edit Profil',
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    _MenuRow(
                      icon: Icons.lock_rounded,
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
                      label: 'Keluar dari Akun',
                      color: AppColors.error,
                      onTap: () async {
                        await auth.logout();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // App version
                  Center(
                    child: Text(
                      'Go-Dah Mobile v1.0.0\nJasa Angkut Barang Mahasiswa',
                      style: AppTextStyles.caption.copyWith(height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
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
