// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/orbital_logo.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  String? _error;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _slideAnim = Tween<Offset>(begin: const Offset(0, .3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideCtrl.forward();
    });
  }

  Future<void> _login() async {
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa usuario y contraseña.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session =
          await ApiService.login(_userCtrl.text.trim(), _passCtrl.text.trim());
      await ApiService.saveSession(session);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(session: session)));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(children: [
        // Fondo
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.5),
                radius: 1.0,
                colors: [Color(0xFF1A1500), Color(0xFF0E0E0E)],
              ),
            ),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo mini + nombre en topbar
                    Row(children: [
                      const OrbitalLogoMini(size: 38),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('GPS Control',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.4)),
                          Text('Panel del cliente',
                              style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 10,
                                  letterSpacing: .3)),
                        ],
                      ),
                    ]),

                    const SizedBox(height: 52),

                    // Headline
                    const Text(
                      'Hola,',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.5,
                        height: 1.05,
                      ),
                    ),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          height: 1.05,
                        ),
                        children: [
                          TextSpan(
                              text: 'bienvenido.',
                              style: TextStyle(color: Color(0xFFD4A853))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Accede para controlar tu flota',
                      style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          height: 1.4),
                    ),

                    const SizedBox(height: 36),

                    // Card formulario
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF2A2A2A), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Campo usuario
                          _FieldLabel('USUARIO'),
                          const SizedBox(height: 8),
                          _DarkField(
                            controller: _userCtrl,
                            hint: 'Tu usuario',
                            icon: Icons.person_outline_rounded,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),

                          // Campo contraseña
                          _FieldLabel('CONTRASEÑA'),
                          const SizedBox(height: 8),
                          _DarkField(
                            controller: _passCtrl,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: !_showPass,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            suffix: IconButton(
                              icon: Icon(
                                  _showPass
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: const Color(0xFF555555)),
                              onPressed: () =>
                                  setState(() => _showPass = !_showPass),
                            ),
                          ),

                          // Error
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F0A0A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF5A1A1A)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 16, color: Color(0xFFE24B4A)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFE24B4A)))),
                              ]),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Botón login
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: GestureDetector(
                              onTap: _loading ? null : _login,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  gradient: _loading
                                      ? null
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFFD4A853),
                                            Color(0xFFC4882A),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  color: _loading
                                      ? const Color(0xFF2A2A2A)
                                      : null,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: _loading
                                      ? []
                                      : [
                                          BoxShadow(
                                              color: const Color(0xFFD4A853)
                                                  .withOpacity(.3),
                                              blurRadius: 20,
                                              offset: const Offset(0, 6)),
                                        ],
                                ),
                                child: Center(
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              color: Color(0xFFD4A853),
                                              strokeWidth: 2))
                                      : const Text(
                                          'Entrar',
                                          style: TextStyle(
                                              color: Color(0xFF1A1000),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: .2),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        '¿Problemas? Contacta a soporte',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF444444)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 9,
            color: Color(0xFFD4A853),
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700),
      );
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _DarkField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E2E2E)),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF444444), fontSize: 14),
            prefixIcon:
                Icon(icon, size: 18, color: const Color(0xFF555555)),
            suffixIcon: suffix,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
}