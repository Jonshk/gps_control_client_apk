import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _showPass = false;
  String? _error;

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
      final session = await ApiService.login(
        _userCtrl.text.trim(),
        _passCtrl.text.trim(),
      );

      await ApiService.saveSession(session);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(session: session)),
      );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark,
      body: Stack(
        children: [
          const _LoginBackground(),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 38, 26, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LoginHeader(),

                  const SizedBox(height: 50),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.teal.withOpacity(0.26)),
                    ),
                    child: const Text(
                      'ACCESO A TU FLOTA',
                      style: TextStyle(
                        color: AppTheme.teal,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 17),

                  const Text(
                    'Controla tu\nvehículo.',
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 1.04,
                      letterSpacing: -1.3,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Ubicación, motor y estado GPS desde un panel seguro para clientes.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.46),
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 34),

                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withOpacity(0.82),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _userCtrl,
                          style: const TextStyle(color: AppTheme.textLight),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Color(0x66F0F6FF),
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: _passCtrl,
                          style: const TextStyle(color: AppTheme.textLight),
                          obscureText: !_showPass,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Color(0x66F0F6FF),
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0x66F0F6FF),
                                size: 20,
                              ),
                              onPressed: () => setState(() => _showPass = !_showPass),
                            ),
                          ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.red.withOpacity(0.22)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: AppTheme.red, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 26),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Entrar'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  Center(
                    child: Text(
                      '¿Problemas? Escríbenos por WhatsApp',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _MiniLogo(),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GPS Control EC',
              style: TextStyle(
                color: AppTheme.textLight,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Panel del cliente',
              style: TextStyle(
                color: Color(0x66F0F6FF),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2537),
            Color(0xFF101827),
          ],
        ),
        border: Border.all(
          color: AppTheme.red.withOpacity(0.32),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.red.withOpacity(0.16),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on_rounded,
        color: AppTheme.red,
        size: 24,
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.05, -0.55),
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
            painter: _LoginMeshPainter(),
          ),
        ),

        Positioned(
          top: -90,
          right: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.red.withOpacity(0.075),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.red.withOpacity(0.12),
                  blurRadius: 70,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: -90,
          left: -80,
          child: Container(
            width: 245,
            height: 245,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.teal.withOpacity(0.065),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.teal.withOpacity(0.12),
                  blurRadius: 70,
                  spreadRadius: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.032)
      ..strokeWidth = 0.8;

    final redPaint = Paint()
      ..color = AppTheme.red.withOpacity(0.095)
      ..style = PaintingStyle.fill;

    final tealPaint = Paint()
      ..color = AppTheme.teal.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final points = <Offset>[
      Offset(size.width * .10, size.height * .12),
      Offset(size.width * .34, size.height * .20),
      Offset(size.width * .68, size.height * .12),
      Offset(size.width * .88, size.height * .28),
      Offset(size.width * .20, size.height * .46),
      Offset(size.width * .52, size.height * .38),
      Offset(size.width * .80, size.height * .52),
      Offset(size.width * .16, size.height * .76),
      Offset(size.width * .48, size.height * .70),
      Offset(size.width * .84, size.height * .82),
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
