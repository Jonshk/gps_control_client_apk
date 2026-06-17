// lib/widgets/orbital_logo.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class OrbitalLogo extends StatefulWidget {
  final double size;
  const OrbitalLogo({super.key, this.size = 160});

  @override
  State<OrbitalLogo> createState() => _OrbitalLogoState();
}

class _OrbitalLogoState extends State<OrbitalLogo>
    with TickerProviderStateMixin {
  late AnimationController _orb1, _orb2, _orb3;
  late AnimationController _ping, _pulse;

  @override
  void initState() {
    super.initState();
    _orb1 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 8000))
      ..repeat();
    _orb2 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 12000))
      ..repeat();
    _orb3 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 18000))
      ..repeat();
    _ping = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orb1.dispose();
    _orb2.dispose();
    _orb3.dispose();
    _ping.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(alignment: Alignment.center, children: [
        // Anillos estáticos
        _Ring(size: s * .42, color: const Color(0xFFD4A853), opacity: .18),
        _Ring(size: s * .58, color: const Color(0xFFD4A853), opacity: .12),
        _Ring(size: s * .74, color: const Color(0xFFD4A853), opacity: .07),

        // Satélites orbitando
        _Satellite(ctrl: _orb1, radius: s * .21, satSize: 7, startAngle: 0),
        _Satellite(
            ctrl: _orb2,
            radius: s * .29,
            satSize: 5,
            startAngle: math.pi * .66,
            reverse: true),
        _Satellite(
            ctrl: _orb3,
            radius: s * .37,
            satSize: 4,
            startAngle: math.pi * 1.33),

        // Ping rings
        _PingRing(ctrl: _ping, size: s * .27, delay: 0),
        _PingRing(ctrl: _ping, size: s * .27, delay: 0.33),
        _PingRing(ctrl: _ping, size: s * .27, delay: 0.66),

        // Core
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Container(
            width: s * .27,
            height: s * .27,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(s * .075),
              border: Border.all(
                  color: Color.lerp(const Color(0x55D4A853),
                      const Color(0xAAD4A853), _pulse.value)!,
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Color.fromRGBO(
                        212, 168, 83, .1 + _pulse.value * .1),
                    blurRadius: 20,
                    spreadRadius: 4),
              ],
            ),
            child: child,
          ),
          child: Center(child: _PinIcon(size: s * .135)),
        ),
      ]),
    );
  }
}

class _Ring extends StatelessWidget {
  final double size, opacity;
  final Color color;
  const _Ring(
      {required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(opacity), width: 1),
        ),
      );
}

class _Satellite extends StatelessWidget {
  final AnimationController ctrl;
  final double radius, satSize, startAngle;
  final bool reverse;
  const _Satellite(
      {required this.ctrl,
      required this.radius,
      required this.satSize,
      required this.startAngle,
      this.reverse = false});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final angle = startAngle +
              (reverse ? -1 : 1) * ctrl.value * math.pi * 2;
          return Transform.translate(
            offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius),
            child: Container(
              width: satSize,
              height: satSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4A853),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFD4A853).withOpacity(.7),
                      blurRadius: 6,
                      spreadRadius: 1),
                ],
              ),
            ),
          );
        },
      );
}

class _PingRing extends StatelessWidget {
  final AnimationController ctrl;
  final double size;
  final double delay;
  const _PingRing(
      {required this.ctrl, required this.size, required this.delay});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final t = ((ctrl.value + delay) % 1.0);
          final scale = 1.0 + t * 1.8;
          final opacity = (1 - t) * .5;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * .28),
                border: Border.all(
                    color: const Color(0xFFD4A853).withOpacity(opacity),
                    width: 1.5),
              ),
            ),
          );
        },
      );
}

class _PinIcon extends StatelessWidget {
  final double size;
  const _PinIcon({required this.size});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size * 1.2),
        painter: _PinPainter(),
      );
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final r = size.width * .38;
    final cy = r + 2;

    // Círculo exterior
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Círculo interior relleno
    canvas.drawCircle(
        Offset(cx, cy),
        r * .38,
        Paint()
          ..color = const Color(0xFFD4A853)
          ..style = PaintingStyle.fill);

    // Palo
    canvas.drawLine(
        Offset(cx, cy + r), Offset(cx, size.height - 4), paint);

    // Punto base
    canvas.drawCircle(
        Offset(cx, size.height - 2),
        2,
        Paint()
          ..color = const Color(0xFFD4A853)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Logo completo con texto ────────────────────────────────────
class OrbitalLogoFull extends StatefulWidget {
  const OrbitalLogoFull({super.key});

  @override
  State<OrbitalLogoFull> createState() => _OrbitalLogoFullState();
}

class _OrbitalLogoFullState extends State<OrbitalLogoFull>
    with TickerProviderStateMixin {
  late AnimationController _barCtrl;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const OrbitalLogo(size: 160),
        const SizedBox(height: 28),
        // GPS
        const Text(
          'GPS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 5,
            color: Color(0xFFD4A853),
          ),
        ),
        const SizedBox(height: 4),
        // Control EC
        const Text(
          'Control EC',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            color: Color(0xFFFFFFFF),
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        // Barras de señal
        AnimatedBuilder(
          animation: _barCtrl,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(4, (i) {
                final delay = i * 0.25;
                final t = ((_barCtrl.value + delay) % 1.0);
                final opacity = .3 + t * .7;
                final heights = [4.0, 7.0, 10.0, 14.0];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 4,
                    height: heights[i],
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A853).withOpacity(opacity),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 10),
        // Subtítulo
        const Text(
          'ECUADOR · FLEET TRACKING',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 3.5,
            color: Color(0xFF555555),
          ),
        ),
      ],
    );
  }
}

// ── Logo pequeño para TopBar/Login ───────────────────────────
class OrbitalLogoMini extends StatefulWidget {
  final double size;
  const OrbitalLogoMini({super.key, this.size = 36});

  @override
  State<OrbitalLogoMini> createState() => _OrbitalLogoMiniState();
}

class _OrbitalLogoMiniState extends State<OrbitalLogoMini>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 8000))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(alignment: Alignment.center, children: [
        // Un solo anillo
        Container(
          width: s * .9,
          height: s * .9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFFD4A853).withOpacity(.25), width: 1),
          ),
        ),
        // Un satélite
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final angle = _ctrl.value * math.pi * 2;
            return Transform.translate(
              offset: Offset(
                  math.cos(angle) * s * .38, math.sin(angle) * s * .38),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4A853),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFD4A853).withOpacity(.8),
                        blurRadius: 4)
                  ],
                ),
              ),
            );
          },
        ),
        // Core
        Container(
          width: s * .58,
          height: s * .58,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(s * .16),
            border: Border.all(
                color: const Color(0xFFD4A853).withOpacity(.4), width: 1),
          ),
          child: Center(child: _PinIcon(size: s * .28)),
        ),
      ]),
    );
  }
}