// ignore: unused_import
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/vehiculo_service.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/features/emergencias/enviar_ubicacion/enviar_ubicacion_page.dart';

// CU05 - Reportar Emergencia
class ReportarEmergenciaPage extends StatefulWidget {
  const ReportarEmergenciaPage({super.key});

  @override
  State<ReportarEmergenciaPage> createState() => _ReportarEmergenciaPageState();
}

class _ReportarEmergenciaPageState extends State<ReportarEmergenciaPage> {
  final _formKey        = GlobalKey<FormState>();
  final _descCtrl       = TextEditingController();
  final _vehiculoSvc    = VehiculoService();
  final _emergenciaSvc  = EmergenciaService();

  List<Map<String, dynamic>> _vehiculos = [];
  int?    _vehiculoId;
  String  _prioridad = 'media';
  bool    _loading   = false;
  bool    _loadingVehiculos = true;
  String  _error     = '';

  static const _prioridades = [
    {'value': 'alta',  'label': 'Alta  — Vehículo inmovilizado'},
    {'value': 'media', 'label': 'Media — Falla parcial'},
    {'value': 'baja',  'label': 'Baja  — Revisión preventiva'},
  ];

  @override
  void initState() {
    super.initState();
    _cargarVehiculos();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarVehiculos() async {
    try {
      final lista = await _vehiculoSvc.listarVehiculos();
      setState(() { _vehiculos = lista; _loadingVehiculos = false; });
    } catch (e) {
      setState(() {
        _error = 'No se pudieron cargar los vehículos';
        _loadingVehiculos = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final incidente = await _emergenciaSvc.crearIncidente(
        vehiculoId:  _vehiculoId!,
        descripcion: _descCtrl.text.trim(),
        prioridad:   _prioridad,
      );
      if (!mounted) return;
      // Navegar a enviar ubicación pasando el id del incidente creado
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EnviarUbicacionPage(incidenteId: incidente['id'] as int),
        ),
      );
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
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        title: const Text('Reportar Emergencia', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: _loadingVehiculos
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner de alerta
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Completa el formulario para solicitar asistencia. '
                              'Al continuar podrás compartir tu ubicación GPS.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Vehículo
                    const _Label('Vehículo *'),
                    const SizedBox(height: 6),
                    if (_vehiculos.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Text(
                          'No tienes vehículos registrados. Registra uno primero.',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _vehiculoId,
                        decoration: _inputDeco('Selecciona tu vehículo'),
                        items: _vehiculos.map((v) => DropdownMenuItem(
                          value: v['id'] as int,
                          child: Text(
                            '${v['marca']} ${v['modelo']} — ${v['placa']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        )).toList(),
                        onChanged: (val) => setState(() => _vehiculoId = val),
                        validator: (v) => v == null ? 'Selecciona un vehículo' : null,
                      ),
                    const SizedBox(height: 18),

                    // Prioridad
                    const _Label('Prioridad *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _prioridad,
                      decoration: _inputDeco('Selecciona la prioridad'),
                      items: _prioridades.map((p) => DropdownMenuItem(
                        value: p['value'],
                        child: Text(p['label']!, style: const TextStyle(fontSize: 14)),
                      )).toList(),
                      onChanged: (val) => setState(() => _prioridad = val ?? 'media'),
                    ),
                    const SizedBox(height: 18),

                    // Descripción
                    const _Label('Descripción del problema'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: _inputDeco('Describe brevemente el problema... (opcional, máx. 1000)'),
                      style: const TextStyle(fontSize: 14),
                      validator: (v) {
                        if (v != null && v.trim().length > 1000) {
                          return 'La descripción no puede exceder 1000 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Error
                    if (_error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Botón
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_loading || _vehiculos.isEmpty) ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _loading ? 'Enviando...' : 'Reportar y compartir ubicación',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.danger)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text));
}
