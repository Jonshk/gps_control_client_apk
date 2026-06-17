// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/orbital_logo.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _loaderCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _loaderWidth;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _loaderCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loaderWidth = CurvedAnimation(parent: _loaderCtrl, curve: Curves.easeInOut);

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _fadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _loaderCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2400));
    _navigate();
  }

  Future<void> _navigate() async {
    final session = await ApiService.loadSession();
    if (!mounted) return;
    if (session != null) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(session: session)));
    } else {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _loaderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(children: [
        // Fondo gradiente sutil
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.2),
                radius: 1.2,
                colors: [Color(0xFF1A1500), Color(0xFF0E0E0E)],
              ),
            ),
          ),
        ),

        // Contenido central
        Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo orbital animado
                const OrbitalLogoFull(),

                const SizedBox(height: 56),

                // Barra de carga
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: AnimatedBuilder(
                    animation: _loaderCtrl,
                    builder: (_, __) => Column(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: SizedBox(
                          height: 2,
                          child: LayoutBuilder(builder: (ctx, constraints) =>
                              Stack(children: [
                                Container(color: const Color(0xFF2A2A2A)),
                                Container(
                                    width: constraints.maxWidth * _loaderWidth.value,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        Color(0xFFD4A853),
                                        Color(0xFFE8C070),
                                      ]),
                                    )),
                              ])),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Iniciando sistema...',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(.25),
                            letterSpacing: 1),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Versión
        const Positioned(
          bottom: 28,
          left: 0,
          right: 0,
          child: Text(
            'v2.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10,
                color: Color(0xFF333333),
                letterSpacing: .5),
          ),
        ),
      ]),
    );
  }
}