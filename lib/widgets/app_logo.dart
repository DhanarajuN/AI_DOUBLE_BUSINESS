import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The app's brand mark: a navy squircle tile holding a lens with a small
/// accent "live" dot. Matches lib/theme/app_theme.dart's chromeGradient and
/// assets/branding/app_icon.svg — keep both in sync if this changes.
class AppLogoMark extends StatelessWidget {
  final double size;
  const AppLogoMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AppLogoPainter()),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    const chrome = Color(0xFF0C1B31);
    const chrome2 = Color(0xFF16294A);
    const paper = Color(0xFFF8FAFC);
    const accent2 = Color(0xFF3B82F6);

    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(100, 100), [chrome, chrome2]);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(2, 2, 96, 96), const Radius.circular(24)),
      bgPaint,
    );

    canvas.drawCircle(const Offset(50, 50), 23, Paint()..color = paper);
    canvas.drawCircle(const Offset(50, 50), 8, Paint()..color = chrome);
    canvas.drawCircle(const Offset(68.5, 31.5), 7.6, Paint()..color = chrome);
    canvas.drawCircle(const Offset(68.5, 31.5), 5.6, Paint()..color = accent2);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
