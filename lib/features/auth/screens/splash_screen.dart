import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.appName,
              style: AppTextStyles.displayMd.copyWith(color: AppColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.appTagline,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.white),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
