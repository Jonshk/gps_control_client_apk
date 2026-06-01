import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _slide;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _slide = Tween<double>(begin: 28.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _rotate = Tween<double>(begin: -0.04, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          const _SplashBackground(),

          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return FadeTransition(
                  opacity: _fade,
                  child: Transform.translate(
                    offset: Offset(0, _slide.value),
                    child: Transform.rotate(
                      angle: _rotate.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(
                            scale: _scale,
                            child: const _PremiumLogo(),
                          ),

                          const SizedBox(height: 28),

                          const Text(
                            'GPS Control EC',
                            style: TextStyle(
                              color: Color(0xFFF0F6FF),
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.1,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Control inteligente de tu vehículo',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.42),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),

                          const SizedBox(height: 18),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D4A0).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF00D4A0).withOpacity(0.28),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00D4A0).withOpacity(0.10),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: const Text(
                              'PANEL DEL CLIENTE',
                              style: TextStyle(
                                color: Color(0xFF00D4A0),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),

                          const SizedBox(height: 58),

                          const _LoadingPulse(),

                          const SizedBox(height: 16),

                          Text(
                            'Cargando sistema GPS...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.32),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fade,
              child: Text(
                'v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.16),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumLogo extends StatelessWidget {
  const _PremiumLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8232A).withOpacity(0.08),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE8232A).withOpacity(0.24),
                  blurRadius: 46,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B2537),
                  Color(0xFF101827),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFE8232A).withOpacity(0.34),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 16,
                  right: 14,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00D4A0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4A0).withOpacity(0.65),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFE8232A),
                  size: 50,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPulse extends StatelessWidget {
  const _LoadingPulse();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFF00D4A0).withOpacity(0.75),
            strokeWidth: 2.3,
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00D4A0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4A0).withOpacity(0.6),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.45),
              radius: 1.25,
              colors: [
                Color(0xFF15243A),
                Color(0xFF0A101D),
                Color(0xFF070B14),
              ],
            ),
          ),
        ),

        Positioned.fill(
          child: CustomPaint(
            painter: _NetworkMeshPainter(),
          ),
        ),

        Positioned(
          top: -110,
          right: -90,
          child: Container(
            width: 310,
            height: 310,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8232A).withOpacity(0.08),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE8232A).withOpacity(0.14),
                  blurRadius: 80,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: -100,
          left: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00D4A0).withOpacity(0.07),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4A0).withOpacity(0.12),
                  blurRadius: 80,
                  spreadRadius: 18,
                ),
              ],
            ),
          ),
        ),

        Positioned(
          top: 120,
          left: -40,
          child: Transform.rotate(
            angle: -0.35,
            child: Container(
              width: 180,
              height: 1,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),

        Positioned(
          bottom: 170,
          right: -30,
          child: Transform.rotate(
            angle: 0.35,
            child: Container(
              width: 220,
              height: 1,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
      ],
    );
  }
}

class _NetworkMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 0.8;

    final redPaint = Paint()
      ..color = const Color(0xFFE8232A).withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final tealPaint = Paint()
      ..color = const Color(0xFF00D4A0).withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final points = <Offset>[
      Offset(size.width * .12, size.height * .18),
      Offset(size.width * .34, size.height * .10),
      Offset(size.width * .62, size.height * .18),
      Offset(size.width * .88, size.height * .12),
      Offset(size.width * .22, size.height * .38),
      Offset(size.width * .50, size.height * .34),
      Offset(size.width * .79, size.height * .42),
      Offset(size.width * .14, size.height * .66),
      Offset(size.width * .42, size.height * .72),
      Offset(size.width * .72, size.height * .63),
      Offset(size.width * .90, size.height * .78),
    ];

    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
      if (i + 2 < points.length && i.isEven) {
        canvas.drawLine(points[i], points[i + 2], linePaint);
      }
    }

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], i.isEven ? 2.5 : 2.0, i.isEven ? redPaint : tealPaint);
    }

    final radarPaint = Paint()
      ..color = const Color(0xFF00D4A0).withOpacity(0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width * 0.50, size.height * 0.42);
    for (final r in [70.0, 118.0, 166.0]) {
      canvas.drawCircle(center, r, radarPaint);
    }

    final sweep = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF00D4A0).withOpacity(0.0),
          const Color(0xFF00D4A0).withOpacity(0.10),
          const Color(0xFF00D4A0).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 170));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 170),
      -math.pi / 2,
      math.pi / 3,
      true,
      sweep,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
