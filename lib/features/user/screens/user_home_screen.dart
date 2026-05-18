import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../state/providers/auth_provider.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
 
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
            const Icon(Icons.home_rounded, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Halo, ${user?.nama ?? 'User'}! 👋',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 8),
            Text(
              'Halaman user sedang dalam pengembangan',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.grey500),
            ),
          ],
        ),
      ),
    );
  }
}