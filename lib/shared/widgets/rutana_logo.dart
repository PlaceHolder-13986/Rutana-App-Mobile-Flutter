import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RutanaLogo extends StatelessWidget {
  final double size;
  const RutanaLogo({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 36 / 38,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {

    canvas.scale(size.width / 38, size.height / 36);

    final yellow = Paint()..color = AppColors.yellow;
    final white = Paint()..color = Colors.white;

    final left = Path()
      ..moveTo(0, 0)..lineTo(12, 0)..lineTo(12, 3)..lineTo(3, 12)..lineTo(0, 12)..close();
    final right = Path()
      ..moveTo(38, 0)..lineTo(26, 0)..lineTo(26, 3)..lineTo(35, 12)..lineTo(38, 12)..close();
    final chevron = Path()
      ..moveTo(19, 3)..lineTo(38, 22)..lineTo(38, 33)..lineTo(36.5, 35)
      ..lineTo(19, 18.5)..lineTo(1.5, 35)..lineTo(0, 33)..lineTo(0, 22)..close();

    canvas.drawPath(left, yellow);
    canvas.drawPath(right, yellow);
    canvas.drawPath(chevron, white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
