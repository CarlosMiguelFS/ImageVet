import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Chuva de confete que dispara uma vez ao aparecer.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.pieces = 140, this.duration = const Duration(milliseconds: 2800)});

  final int pieces;
  final Duration duration;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<_Piece> _pieces = _generate();

  static const _colors = [
    AppColors.brand400,
    AppColors.brand600,
    AppColors.clayInk,
    AppColors.mintInk,
    AppColors.amberInk,
    AppColors.stoneInk,
    Color(0xFFFFD36B),
  ];

  List<_Piece> _generate() {
    final rng = Random();
    return List.generate(widget.pieces, (_) {
      final angle = -pi / 2 + (rng.nextDouble() - 0.5) * pi * 0.9;
      final speed = 0.55 + rng.nextDouble() * 0.75;
      return _Piece(
        originX: 0.3 + rng.nextDouble() * 0.4,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed * 1.4,
        color: _colors[rng.nextInt(_colors.length)],
        size: 6 + rng.nextDouble() * 7,
        spin: (rng.nextDouble() - 0.5) * 18,
        round: rng.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _controller.value)),
    ),
  );
}

class _Piece {
  const _Piece({
    required this.originX,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.spin,
    required this.round,
  });

  final double originX, vx, vy, size, spin;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
    for (final p in pieces) {
      // Lançamento para cima, depois a gravidade puxa para baixo.
      final x = size.width * (p.originX + p.vx * t * 0.6);
      final y = size.height * (0.55 + p.vy * t * 0.9 + 1.6 * t * t);
      if (y > size.height + 20) continue;
      final paint = Paint()..color = p.color.withValues(alpha: fade.clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
