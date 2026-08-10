import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// The viewfinder mark on the idle scan screen: four corner arcs and four
/// centre ticks, nothing in between.
///
/// It reads as "aim here" without being a photograph of a product, which
/// matters on a screen whose entire argument is that it does not show you
/// things it hasn't seen. A stock product illustration in this slot would be
/// the first fabricated image in an app built to avoid fabrication.
class ScanFrame extends StatelessWidget {
  const ScanFrame({super.key, this.size = 190});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const _ScanFramePainter(),
        child: Center(
          child: Icon(
            Icons.center_focus_weak_outlined,
            size: 40,
            color: AppColors.brand.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brand
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final inset = size.width * 0.06;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final cornerRadius = rect.width * 0.14;

    final innerWidth = rect.width - cornerRadius * 2;
    final innerHeight = rect.height - cornerRadius * 2;
    final segmentLength = math.min(innerWidth, innerHeight) * 0.24;

    void drawCenterHorizontal(double y) {
      canvas.drawLine(
        Offset(rect.center.dx - segmentLength / 2, y),
        Offset(rect.center.dx + segmentLength / 2, y),
        paint,
      );
    }

    void drawCenterVertical(double x) {
      canvas.drawLine(
        Offset(x, rect.center.dy - segmentLength / 2),
        Offset(x, rect.center.dy + segmentLength / 2),
        paint,
      );
    }

    drawCenterHorizontal(rect.top);
    drawCenterHorizontal(rect.bottom);
    drawCenterVertical(rect.left);
    drawCenterVertical(rect.right);

    void drawCorner(Offset centre, double startAngle) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: cornerRadius),
        startAngle,
        math.pi / 2,
        false,
        paint,
      );
    }

    drawCorner(
      Offset(rect.left + cornerRadius, rect.top + cornerRadius),
      math.pi,
    );
    drawCorner(
      Offset(rect.right - cornerRadius, rect.top + cornerRadius),
      -math.pi / 2,
    );
    drawCorner(
      Offset(rect.right - cornerRadius, rect.bottom - cornerRadius),
      0,
    );
    drawCorner(
      Offset(rect.left + cornerRadius, rect.bottom - cornerRadius),
      math.pi / 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
