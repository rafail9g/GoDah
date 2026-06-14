  import 'package:flutter/material.dart';
  import '../../../core/constants/app_colors.dart';
  import '../../../core/constants/app_strings.dart';
  import '../../../core/constants/app_text_styles.dart';
<<<<<<< Updated upstream
=======
  import '../../../core/widgets/brand_video_logo.dart';
>>>>>>> Stashed changes

  class SplashScreen extends StatelessWidget {
    const SplashScreen({super.key});

    @override
    Widget build(BuildContext context) {
      return Scaffold(
<<<<<<< Updated upstream
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1E3C72),
                Color(0xFF2A5298),
              ],
            ),
          ),
=======
        backgroundColor: AppColors.white,
        body: Container(
          color: AppColors.white,
>>>>>>> Stashed changes
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
<<<<<<< Updated upstream
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 52,
                    color: Color(0xFF1E3C72),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.appName,
                  style: AppTextStyles.displayMd.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.appTagline,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 64),
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                      minHeight: 3,
                    ),
                  ),
                ),
=======
                const BrandVideoLogo(
                  asset: 'assets/branding/splash.mp4',
                  width: 180,
                  height: 180,
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.appName,
                  style: AppTextStyles.displayMd.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.appTagline,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.grey800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 64),
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                      minHeight: 3,
                    ),
                  ),
                ),
>>>>>>> Stashed changes
              ],
            ),
          ),
        ),
      );
    }
  }
