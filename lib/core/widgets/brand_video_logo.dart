import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class BrandVideoLogo extends StatefulWidget {
  final String asset;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const BrandVideoLogo({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  @override
  State<BrandVideoLogo> createState() => _BrandVideoLogoState();
}

class _BrandVideoLogoState extends State<BrandVideoLogo> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.asset)
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.seekTo(Duration.zero);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _controller.value.isInitialized
        ? FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          )
        : const SizedBox.shrink();

    final logo = SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );

    if (widget.borderRadius == null) return logo;

    return ClipRRect(
      borderRadius: widget.borderRadius!,
      child: logo,
    );
  }
}
