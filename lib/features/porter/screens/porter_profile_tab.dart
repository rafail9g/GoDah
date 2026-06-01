import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';

class PorterProfileTab extends StatelessWidget {
  const PorterProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final porter = auth.currentPorter;

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
                      porter?.nama.isNotEmpty == true
                          ? porter!.nama[0].toUpperCase()
                          : 'P',
                      style: AppTextStyles.displayMd.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(porter?.nama ?? '-', style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                  Text(porter?.email ?? '-',
                      style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey500)),
                  const SizedBox(height: 8),
                  _VerifBadge(status: porter?.statusVerifikasi ?? 'menunggu'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info
            _InfoCard(children: [
              _InfoRow(icon: Icons.phone_outlined, label: 'No. HP', value: porter?.noHp ?? '-'),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Total Selesai',
                value: '${porter?.totalSelesai ?? 0} order',
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Status Verifikasi',
                value: _verifLabel(porter?.statusVerifikasi ?? ''),
              ),
            ]),
            const SizedBox(height: 16),

            // Menu
            _InfoCard(children: [
              _MenuRow(
                icon: Icons.upload_file_rounded,
                label: 'Verifikasi Dokumen',
                onTap: () => context.push('/porter/verification'),
              ),
              const Divider(height: 1),
              _MenuRow(
                icon: Icons.help_outline_rounded,
                label: 'Bantuan',
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
          ],
        ),
      ),
    );
  }

  String _verifLabel(String s) => switch (s) {
    'disetujui' => 'Terverifikasi',
    'ditolak' => 'Ditolak',
    _ => 'Menunggu Review',
  };
}

class _VerifBadge extends StatelessWidget {
  final String status;
  const _VerifBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (status) {
      'disetujui' => (AppColors.success, 'Terverifikasi', Icons.verified_rounded),
      'ditolak' => (AppColors.error, 'Ditolak', Icons.cancel_rounded),
      _ => (AppColors.warning, 'Menunggu Verifikasi', Icons.hourglass_top_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusRound),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: color)),
        ],
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

  const _InfoRow({required this.icon, required this.label, required this.value});

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
          Text(value, style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey600)),
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
