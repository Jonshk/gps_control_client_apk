import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
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
    setState(() { _loading = true; _error = null; });
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on, color: AppTheme.red, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GPS Control EC',
                      style: TextStyle(color: AppTheme.textLight, fontSize: 16,
                          fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                    Text('Panel del cliente',
                      style: TextStyle(color: Color(0x66F0F6FF), fontSize: 11)),
                  ],
                ),
              ]),

              const SizedBox(height: 56),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.teal.withOpacity(0.25)),
                ),
                child: const Text('ACCESO A TU FLOTA',
                  style: TextStyle(color: AppTheme.teal, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.0)),
              ),

              const SizedBox(height: 16),

              const Text('Controla tu\nvehículo.',
                style: TextStyle(color: AppTheme.textLight, fontSize: 38,
                    fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -1.2)),

              const SizedBox(height: 8),

              Text('Usa las credenciales que te enviamos al contratar el servicio.',
                style: TextStyle(color: Colors.white.withOpacity(0.45),
                    fontSize: 14, height: 1.6)),

              const SizedBox(height: 40),

              // Usuario
              TextField(
                controller: _userCtrl,
                style: const TextStyle(color: AppTheme.textLight),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person_outline,
                      color: Color(0x66F0F6FF), size: 20),
                ),
              ),

              const SizedBox(height: 14),

              // Contraseña
              TextField(
                controller: _passCtrl,
                style: const TextStyle(color: AppTheme.textLight),
                obscureText: !_showPass,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: Color(0x66F0F6FF), size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0x66F0F6FF), size: 20),
                    onPressed: () => setState(() => _showPass = !_showPass),
                  ),
                ),
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.red.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppTheme.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(color: AppTheme.red, fontSize: 13))),
                  ]),
                ),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Entrar'),
                ),
              ),

              const SizedBox(height: 28),

              Center(
                child: Text('¿Problemas? Escríbenos por WhatsApp',
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
