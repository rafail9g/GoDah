import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';

class PorterHomeScreen extends StatelessWidget {
  const PorterHomeScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final porter = auth.currentPorter;
 
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
 
            if (porter != null && !porter.isVerified) ...[
              // Banner verifikasi
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.badge_outlined,
                          color: AppColors.warning, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Akun Belum Terverifikasi',
                        style: AppTextStyles.h3
                            .copyWith(color: AppColors.warning),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload dokumen identitas untuk mulai menerima pesanan.',
                        style: AppTextStyles.bodyMd
                            .copyWith(color: AppColors.grey600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/porter/verification'),
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Upload Dokumen'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Icon(Icons.directions_run_rounded,
                  size: 64, color: AppColors.accent700),
              const SizedBox(height: 16),
              Text(
                'Halo, ${porter?.nama ?? 'Porter'}! 👋',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 8),
              Text(
                'Halaman porter sedang dalam pengembangan',
                style:
                    AppTextStyles.bodyMd.copyWith(color: AppColors.grey500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}