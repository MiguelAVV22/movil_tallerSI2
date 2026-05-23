// ignore: unused_import
import 'dart:convert';
import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:http/http.dart' as http;
import 'package:taller_movil/core/theme/app_colors.dart';

// CU03 - Registrar Vehículo
import 'package:taller_movil/services/vehiculo_service.dart';
import 'package:taller_movil/services/api_helper.dart';

class RegistrarVehiculoPage extends StatefulWidget {
  const RegistrarVehiculoPage({super.key});

  @override
  State<RegistrarVehiculoPage> createState() => _RegistrarVehiculoPageState();
}

class _RegistrarVehiculoPageState extends State<RegistrarVehiculoPage> {
  final _formKey = GlobalKey<FormState>();
  final _service  = VehiculoService();

  final _placaCtrl  = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl   = TextEditingController();

  String? _marca;
  String? _color;
  bool _loading = false;
  String _error = '';
  bool _success = false;

  static const _marcas = [
    'Toyota', 'Hyundai', 'Chevrolet', 'Nissan', 'Ford',
    'Kia', 'Honda', 'Mazda', 'Mitsubishi', 'Volkswagen', 'Otro',
  ];

  static const _colores = [
    'Blanco', 'Negro', 'Gris', 'Plata', 'Rojo',
    'Azul', 'Verde', 'Amarillo', 'Naranja', 'Café', 'Otro',
  ];

  @override
  void dispose() {
    _placaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = ''; });

    try {
      await _service.registrarVehiculo(
        placa:  _placaCtrl.text.trim().toUpperCase(),
        marca:  _marca!,
        modelo: _modeloCtrl.text.trim(),
        anio:   int.parse(_anioCtrl.text.trim()),
        color:  _color!,
      );
      setState(() { _success = true; _loading = false; });
    } catch (e) {
      if (e is TokenExpiradoException) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Registrar Vehículo', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _success ? _SuccessBanner(onNew: () => setState(() {
          _success = false;
          _placaCtrl.clear();
          _modeloCtrl.clear();
          _anioCtrl.clear();
          _marca = null;
          _color = null;
        })) : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Registrar Vehículo',
          subtitle: 'Agrega un vehículo a tu cuenta (CU03)',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _Field(
                  label: 'Placa *',
                  controller: _placaCtrl,
                  hint: 'Ej: ABC-1234',
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'La placa es requerida';
                    if (v.trim().length < 5) return 'Mínimo 5 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _DropdownField(
                  label: 'Marca *',
                  value: _marca,
                  items: _marcas,
                  onChanged: (v) => setState(() => _marca = v),
                  validator: (v) => v == null ? 'Selecciona una marca' : null,
                ),
                const SizedBox(height: 16),
                _Field(
                  label: 'Modelo *',
                  controller: _modeloCtrl,
                  hint: 'Ej: Corolla',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'El modelo es requerido' : null,
                ),
                const SizedBox(height: 16),
                _Field(
                  label: 'Año *',
                  controller: _anioCtrl,
                  hint: 'Ej: 2020',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'El año es requerido';
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1900 || n > 2100) return 'Año inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _DropdownField(
                  label: 'Color *',
                  value: _color,
                  items: _colores,
                  onChanged: (v) => setState(() => _color = v),
                  validator: (v) => v == null ? 'Selecciona un color' : null,
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancelar', style: TextStyle(color: AppColors.text)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Registrar Vehículo', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('¡Vehículo registrado!',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ]),
          const SizedBox(height: 10),
          const Text('Tu vehículo ha sido registrado exitosamente.',
            style: TextStyle(color: Color(0xFF065F46), fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onNew,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Agregar otro'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.validator,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.validator,
  });
  final String label;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        ),
      ],
    );
  }
}
