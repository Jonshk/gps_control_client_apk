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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _slide = Tween(begin: 30.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

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
      backgroundColor: const Color(0xFF0A1628),
      body: Stack(children: [
        // Fondo con gradiente sutil
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: [Color(0xFF0F1F36), Color(0xFF0A1628)],
            ),
          ),
        ),

        // Círculo decorativo rojo difuminado
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8232A).withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00D4A0).withOpacity(0.05),
            ),
          ),
        ),

        // Contenido central
        Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => FadeTransition(
              opacity: _fade,
              child: Transform.translate(
                offset: Offset(0, _slide.value),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Icono con efecto escala
                  ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: const Color(0xFFE8232A).withOpacity(0.12),
                        border: Border.all(
                          color: const Color(0xFFE8232A).withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE8232A).withOpacity(0.15),
                            blurRadius: 32,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFE8232A),
                        size: 44,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nombre
                  const Text(
                    'GPS Control EC',
                    style: TextStyle(
                      color: Color(0xFFF0F6FF),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4A0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: const Color(0xFF00D4A0).withOpacity(0.25)),
                    ),
                    child: const Text(
                      'PANEL DEL CLIENTE',
                      style: TextStyle(
                        color: Color(0xFF00D4A0),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 56),

                  // Spinner
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: const Color(0xFF00D4A0).withOpacity(0.7),
                      strokeWidth: 2,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Cargando...',
                    style: TextStyle(
                      color: const Color(0xFFF0F6FF).withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),

        // Versión abajo
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
                color: const Color(0xFFF0F6FF).withOpacity(0.15),
                fontSize: 11,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
