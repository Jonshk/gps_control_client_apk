import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A1628),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const GpsControlApp());
}

class GpsControlApp extends StatelessWidget {
  const GpsControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Control EC',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const _SplashRouter(),
    );
  }
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();
  @override State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final session = await ApiService.loadSession();
    if (!mounted) return;

    if (session != null) {
      try {
        await ApiService.getStatus(session.token);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(session: session)),
        );
        return;
      } catch (_) {
        await ApiService.clearSession();
      }
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A1628),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on, color: Color(0xFFE8232A), size: 52),
          SizedBox(height: 16),
          Text('GPS Control EC',
            style: TextStyle(color: Color(0xFFF0F6FF), fontSize: 22,
                fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          SizedBox(height: 32),
          SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(
                color: Color(0xFF00D4A0), strokeWidth: 2)),
        ]),
      ),
    );
  }
}
