import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/auth_service.dart';
import 'package:taller_movil/features/acceso_registro/iniciar_sesion/iniciar_sesion_page.dart';

class RecuperarContrasenaPage extends StatefulWidget {
  const RecuperarContrasenaPage({super.key});

  @override
  State<RecuperarContrasenaPage> createState() => _RecuperarContrasenaPageState();
}

class _RecuperarContrasenaPageState extends State<RecuperarContrasenaPage> {
  final _emailFormKey  = GlobalKey<FormState>();
  final _resetFormKey  = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _codeCtrl      = TextEditingController();
  final _newCtrl       = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _auth          = AuthService();

  int _step            = 1; // 1 = email, 2 = código + contraseña
  String _emailEnviado = '';
  bool _loading        = false;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  String _serverError  = '';
  bool _success        = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Paso 1: enviar código ──────────────────────────────────
  Future<void> _submitEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() { _loading = true; _serverError = ''; });
    try {
      await _auth.requestReset(_emailCtrl.text.trim());
      if (mounted) {
        setState(() {
          _emailEnviado = _emailCtrl.text.trim();
          _step = 2;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverError = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  // ── Paso 2: verificar código y nueva contraseña ────────────
  Future<void> _submitReset() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() { _loading = true; _serverError = ''; });
    try {
      await _auth.resetPassword(
        _emailEnviado,
        _codeCtrl.text.trim(),
        _newCtrl.text,
      );
      if (mounted) {
        setState(() { _success = true; _loading = false; });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverError = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _volverPaso1() {
    setState(() {
      _step = 1;
      _serverError = '';
      _codeCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'RutaSegura',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Restablece tu contraseña',
                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                _Card(
                  child: _success
                    ? _buildSuccess()
                    : _step == 1
                      ? _buildStep1()
                      : _buildStep2(),
                ),
                const SizedBox(height: 20),
                AuthFooterLink(
                  text: '',
                  linkText: 'Volver al inicio de sesión',
                  onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Paso 1 ─────────────────────────────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ingresa tu correo y te enviaremos un código de 6 dígitos.',
            style: TextStyle(color: AppColors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          AuthField(
            controller: _emailCtrl,
            label: 'Correo electrónico',
            hint: 'tu@correo.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
              return null;
            },
          ),
          if (_serverError.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_serverError,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Enviar código',
            loading: _loading,
            onPressed: _submitEmail,
          ),
        ],
      ),
    );
  }

  // ── Paso 2 ─────────────────────────────────────────────────
  Widget _buildStep2() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Enviamos un código a $_emailEnviado.\nRevisa también tu bandeja de spam.',
              style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          AuthField(
            controller: _codeCtrl,
            label: 'Código de verificación',
            hint: '123456',
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              if (v.length != 6) return 'El código tiene 6 dígitos';
              return null;
            },
          ),
          const SizedBox(height: 16),
          AuthField(
            controller: _newCtrl,
            label: 'Nueva contraseña',
            hint: '••••••••',
            obscure: _obscureNew,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.grey, size: 20),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              if (v.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 16),
          AuthField(
            controller: _confirmCtrl,
            label: 'Confirmar contraseña',
            hint: '••••••••',
            obscure: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.grey, size: 20),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo requerido';
              if (v != _newCtrl.text) return 'Las contraseñas no coinciden';
              return null;
            },
          ),
          if (_serverError.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_serverError,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Restablecer contraseña',
            loading: _loading,
            onPressed: _submitReset,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _volverPaso1,
            child: const Text('← Cambiar correo',
                style: TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: const [
        Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
        SizedBox(height: 12),
        Text('Contraseña restablecida',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
        SizedBox(height: 6),
        Text('Redirigiendo al inicio de sesión…',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey, fontSize: 13)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
