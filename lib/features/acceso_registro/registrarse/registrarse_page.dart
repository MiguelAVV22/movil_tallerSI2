import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/features/acceso_registro/iniciar_sesion/iniciar_sesion_page.dart';
import 'package:taller_movil/services/auth_service.dart';

// CU01 - Registrarse
class RegistrarsePage extends StatefulWidget {
  const RegistrarsePage({super.key});

  @override
  State<RegistrarsePage> createState() => _RegistrarsePageState();
}

class _RegistrarsePageState extends State<RegistrarsePage> {
  final _formKey         = GlobalKey<FormState>();
  final _emailCtrl       = TextEditingController();
  final _usernameCtrl    = TextEditingController();
  final _fullNameCtrl    = TextEditingController();
  final _telefonoCtrl    = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmPwdCtrl  = TextEditingController();
  final _authService     = AuthService();

  bool _loading         = false;
  bool _obscurePwd      = true;
  bool _obscureConfirm  = true;
  String _serverError   = '';
  List<Map<String, dynamic>> _tenants = [];
  int? _selectedTenantId;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    try {
      final tenants = await _authService.getPublicTenants();
      setState(() {
        _tenants = tenants;
        if (tenants.isNotEmpty) {
          _selectedTenantId = tenants.first['id'] as int;
        }
      });
    } catch (e) {
      debugPrint('Error al cargar tenants: $e');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenantId == null) {
      setState(() { _serverError = 'Por favor selecciona una red de talleres'; });
      return;
    }
    setState(() { _loading = true; _serverError = ''; });
    try {
      await _authService.register(
        email:    _emailCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        tenantId: _selectedTenantId!,
        fullName: _fullNameCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
      );
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
                  'Crea tu cuenta',
                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Container(
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
                          controller: _usernameCtrl,
                          label: 'Nombre de usuario',
                          hint: 'mi_usuario',
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Campo requerido';
                            if (v.length < 3) return 'Mínimo 3 caracteres';
                            if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                              return 'Solo letras, números y guion bajo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthField(
                          controller: _fullNameCtrl,
                          label: 'Nombre completo (opcional)',
                          hint: 'Juan Pérez',
                        ),
                        const SizedBox(height: 16),
                        AuthField(
                          controller: _telefonoCtrl,
                          label: 'Teléfono (opcional)',
                          hint: '+591 70000000',
                          keyboardType: TextInputType.phone,
                        ),
                        if (_tenants.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Red de Talleres',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: _selectedTenantId,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            items: _tenants.map((t) {
                              return DropdownMenuItem<int>(
                                value: t['id'] as int,
                                child: Text(
                                  t['nombre'] as String,
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() { _selectedTenantId = val; });
                            },
                            validator: (v) => v == null ? 'Selección requerida' : null,
                          ),
                        ],
                        const SizedBox(height: 16),
                        AuthField(
                          controller: _passwordCtrl,
                          label: 'Contraseña',
                          hint: '••••••••',
                          obscure: _obscurePwd,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePwd ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.grey, size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Campo requerido';
                            if (v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthField(
                          controller: _confirmPwdCtrl,
                          label: 'Confirmar contraseña',
                          hint: '••••••••',
                          obscure: _obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.grey, size: 20,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Campo requerido';
                            if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
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
                          label: 'Crear cuenta',
                          loading: _loading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AuthFooterLink(
                  text: '¿Ya tienes cuenta? ',
                  linkText: 'Inicia sesión',
                  onTap: () => Navigator.pushNamed(context, '/login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
