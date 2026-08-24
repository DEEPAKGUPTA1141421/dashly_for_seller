import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// Pushes a fullscreen, pinch-to-zoom viewer for [image].
/// [image] should be a pre-built Image / CachedNetworkImage widget.
void showFullScreenImage(BuildContext context, Widget image) {
  Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, animation, __) => FadeTransition(
      opacity: animation,
      child: _FullScreenImageViewer(image: image),
    ),
  ));
}

class _FullScreenImageViewer extends StatelessWidget {
  final Widget image;
  const _FullScreenImageViewer({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(child: image),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface2.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.close_rounded, color: AppColors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
