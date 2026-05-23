import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/auth_service.dart';
import 'package:taller_movil/shared/app_drawer.dart';

class CambiarContrasenaPage extends StatefulWidget {
  const CambiarContrasenaPage({super.key});

  @override
  State<CambiarContrasenaPage> createState() => _CambiarContrasenaPageState();
}

class _CambiarContrasenaPageState extends State<CambiarContrasenaPage> {
  final _formKey        = GlobalKey<FormState>();
  final _currentCtrl    = TextEditingController();
  final _newCtrl        = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  final _auth           = AuthService();

  bool _loading           = false;
  bool _obscureCurrent    = true;
  bool _obscureNew        = true;
  bool _obscureConfirm    = true;
  String _serverError     = '';
  bool _success           = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _serverError = ''; });
    try {
      await _auth.changePassword(_currentCtrl.text, _newCtrl.text);
      if (mounted) {
        setState(() { _success = true; _loading = false; });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cambiar Contraseña',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _success ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
          const SizedBox(height: 12),
          const Text('Contraseña actualizada',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text('Tu contraseña se cambió correctamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Ir al inicio',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PasswordField(
              controller: _currentCtrl,
              label: 'Contraseña actual',
              obscure: _obscureCurrent,
              onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller: _newCtrl,
              label: 'Nueva contraseña',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller: _confirmCtrl,
              label: 'Confirmar nueva contraseña',
              obscure: _obscureConfirm,
              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.65),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: const TextStyle(color: AppColors.grey),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.grey,
                size: 20,
              ),
              onPressed: onToggle,
            ),
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

  OutlineInputBorder _border(Color color, {double width = 1.0}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color, width: width),
  );
}
