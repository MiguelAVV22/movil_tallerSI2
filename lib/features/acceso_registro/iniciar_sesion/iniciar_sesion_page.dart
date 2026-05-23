import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/auth_service.dart';

// CU02 - Iniciar Sesión
class IniciarSesionPage extends StatefulWidget {
  const IniciarSesionPage({super.key});

  @override
  State<IniciarSesionPage> createState() => _IniciarSesionPageState();
}

class _IniciarSesionPageState extends State<IniciarSesionPage> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService  = AuthService();

  bool _loading         = false;
  bool _obscurePassword = true;
  String _serverError   = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _serverError = ''; });
    try {
      await _authService.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      setState(() { _serverError = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                  'Inicia sesión en tu cuenta',
                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                _AuthCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                        const SizedBox(height: 16),
                        AuthField(
                          controller: _passwordCtrl,
                          label: 'Contraseña',
                          hint: '••••••••',
                          obscure: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.grey,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Campo requerido';
                            if (v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),
                        if (_serverError.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _serverError,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          label: 'Iniciar sesión',
                          loading: _loading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AuthFooterLink(
                  text: '¿No tienes cuenta? ',
                  linkText: 'Regístrate aquí',
                  onTap: () => Navigator.pushNamed(context, '/registro'),
                ),
                const SizedBox(height: 10),
                AuthFooterLink(
                  text: '¿Olvidaste tu contraseña? ',
                  linkText: 'Recupérala aquí',
                  onTap: () => Navigator.pushNamed(context, '/recuperar-contrasena'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets reutilizables de autenticación ───────────────────

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});
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

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.grey, fontSize: 14),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border:             _border(AppColors.border),
            enabledBorder:      _border(AppColors.border),
            focusedBorder:      _border(AppColors.primary, width: 1.5),
            errorBorder:        _border(AppColors.danger),
            focusedErrorBorder: _border(AppColors.danger, width: 1.5),
            errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.0}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.65),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: loading
        ? const SizedBox(
            height: 20, width: 20,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
        : Text(label,
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.text,
    required this.linkText,
    required this.onTap,
  });

  final String text;
  final String linkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
        GestureDetector(
          onTap: onTap,
          child: Text(linkText,
            style: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }
}
