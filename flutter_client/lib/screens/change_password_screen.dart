import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String token;
  const ChangePasswordScreen({super.key, required this.token});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading     = false;
  bool _showCurrent = false;
  bool _showNew     = false;
  bool _showConfirm = false;
  String? _error;
  bool _success     = false;

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final newPwd  = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Completa todos los campos.');
      return;
    }
    if (newPwd.length < 6) {
      setState(() => _error = 'La nueva contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (newPwd != confirm) {
      setState(() => _error = 'Las contraseñas nuevas no coinciden.');
      return;
    }
    if (newPwd == current) {
      setState(() => _error = 'La nueva contraseña debe ser diferente a la actual.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await ApiService.changePassword(widget.token, current, newPwd);
      setState(() { _success = true; _loading = false; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Cambiar contraseña',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Icono
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.teal.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: AppTheme.teal, size: 34),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: Text(
                  'Nueva contraseña',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Ingresa tu contraseña actual y la nueva.',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),

              // Formulario
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Column(
                  children: [
                    _buildField(
                      controller: _currentCtrl,
                      label: 'Contraseña actual',
                      icon: Icons.lock_outline_rounded,
                      obscure: !_showCurrent,
                      toggle: () => setState(() => _showCurrent = !_showCurrent),
                      showToggle: _showCurrent,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _newCtrl,
                      label: 'Nueva contraseña',
                      icon: Icons.lock_open_rounded,
                      obscure: !_showNew,
                      toggle: () => setState(() => _showNew = !_showNew),
                      showToggle: _showNew,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _confirmCtrl,
                      label: 'Confirmar nueva contraseña',
                      icon: Icons.check_circle_outline_rounded,
                      obscure: !_showConfirm,
                      toggle: () => setState(() => _showConfirm = !_showConfirm),
                      showToggle: _showConfirm,
                      onSubmit: _submit,
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
                              child: Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_success) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16a34a).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF16a34a).withOpacity(0.22)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Color(0xFF16a34a), size: 16),
                            SizedBox(width: 8),
                            Text('¡Contraseña actualizada!', style: TextStyle(color: Color(0xFF16a34a), fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading || _success ? null : _submit,
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Cambiar contraseña'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback toggle,
    required bool showToggle,
    VoidCallback? onSubmit,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppTheme.textLight),
      obscureText: obscure,
      textInputAction: onSubmit != null ? TextInputAction.done : TextInputAction.next,
      onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0x66F0F6FF), size: 20),
        suffixIcon: IconButton(
          icon: Icon(showToggle ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0x66F0F6FF), size: 20),
          onPressed: toggle,
        ),
      ),
    );
  }
}