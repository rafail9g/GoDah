import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _isVideoReady = false;

  @override
  void initState() {
    super.initState();

    if (!_supportsSplashVideo) return;

    final controller = VideoPlayerController.asset(
      'assets/branding/splash.mp4',
    );
    _controller = controller
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;

        setState(() => _isVideoReady = true);
        controller.play();
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _supportsSplashVideo {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: _isVideoReady && _controller != null
                    ? FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      )
                    : Image.asset(
                        'assets/branding/app_icon.png',
                        fit: BoxFit.contain,
                      ),
              ),
              const SizedBox(height: 28),
              Text(
                AppStrings.appName,
                style: AppTextStyles.displayMd.copyWith(
                  color: AppColors.grey900,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.appTagline,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 56),
              Text(
                'Loading...',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.grey600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
