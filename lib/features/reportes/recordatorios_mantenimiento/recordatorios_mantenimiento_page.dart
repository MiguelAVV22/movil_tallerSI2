import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:taller_movil/core/config/app_config.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/auth_service.dart';
import 'package:taller_movil/services/api_helper.dart';

class RecordatoriosMantenimientoPage extends StatefulWidget {
  const RecordatoriosMantenimientoPage({super.key});

  @override
  State<RecordatoriosMantenimientoPage> createState() =>
      _RecordatoriosMantenimientoPageState();
}

class _RecordatoriosMantenimientoPageState
    extends State<RecordatoriosMantenimientoPage> {
  final _auth = AuthService();
  List<Map<String, dynamic>> _recordatorios = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final token = await _auth.getToken();
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/reportes/mantenimiento'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 401 || res.statusCode == 403) throw TokenExpiradoException();
      verificarRespuesta(res);
      final data = jsonDecode(res.body) as List;
      setState(() {
        _recordatorios = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (e is TokenExpiradoException && mounted) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Color _urgenciaColor(String? urgencia) {
    switch (urgencia) {
      case 'alta': return AppColors.danger;
      case 'media': return const Color(0xFFD97706);
      case 'baja': return AppColors.success;
      case 'sin_historial': return AppColors.primary;
      default: return AppColors.grey;
    }
  }

  IconData _urgenciaIcon(String? urgencia) {
    switch (urgencia) {
      case 'alta': return Icons.warning_rounded;
      case 'media': return Icons.notifications_active_outlined;
      case 'baja': return Icons.schedule_outlined;
      case 'sin_historial': return Icons.info_outline;
      default: return Icons.build_outlined;
    }
  }

  String _urgenciaLabel(String? urgencia) {
    switch (urgencia) {
      case 'alta': return 'URGENTE';
      case 'media': return 'Próximo';
      case 'baja': return 'Pronto';
      case 'sin_historial': return 'Sin historial';
      default: return urgencia ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Recordatorios de Mantenimiento',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(_error, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : _recordatorios.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 60, color: AppColors.success),
                            SizedBox(height: 16),
                            Text('¡Todo al día!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                            SizedBox(height: 8),
                            Text('Tus vehículos no tienen mantenimientos pendientes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.grey)),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recordatorios.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _RecordatorioCard(
                          rec: _recordatorios[i],
                          urgenciaColor: _urgenciaColor(_recordatorios[i]['urgencia'] as String?),
                          urgenciaIcon: _urgenciaIcon(_recordatorios[i]['urgencia'] as String?),
                          urgenciaLabel: _urgenciaLabel(_recordatorios[i]['urgencia'] as String?),
                          onSolicitarServicio: () => _solicitarServicio(_recordatorios[i]),
                        ),
                      ),
                    ),
    );
  }

  void _solicitarServicio(Map<String, dynamic> rec) {
    Navigator.pushNamed(context, '/emergencias/reportar');
  }
}

class _RecordatorioCard extends StatelessWidget {
  const _RecordatorioCard({
    required this.rec,
    required this.urgenciaColor,
    required this.urgenciaIcon,
    required this.urgenciaLabel,
    required this.onSolicitarServicio,
  });

  final Map<String, dynamic> rec;
  final Color urgenciaColor;
  final IconData urgenciaIcon;
  final String urgenciaLabel;
  final VoidCallback onSolicitarServicio;

  @override
  Widget build(BuildContext context) {
    final marca = rec['marca'] as String? ?? '';
    final modelo = rec['modelo'] as String? ?? '';
    final placa = rec['placa'] as String? ?? '';
    final anio = rec['anio'] as int?;
    final dias = rec['dias_desde_ultimo_servicio'] as int?;
    final mensaje = rec['mensaje'] as String? ?? '';
    final intervalo = rec['intervalo_recomendado'] as int?;
    final recurrentes = (rec['problemas_recurrentes'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgenciaColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con urgencia
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: urgenciaColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(urgenciaIcon, color: urgenciaColor, size: 18),
                const SizedBox(width: 8),
                Text(urgenciaLabel,
                  style: TextStyle(
                    color: urgenciaColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (dias != null)
                  Text('$dias días sin servicio',
                    style: TextStyle(color: urgenciaColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehículo
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: urgenciaColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.directions_car, color: urgenciaColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$marca $modelo',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.text,
                            ),
                          ),
                          Text('$placa${anio != null ? ' · $anio' : ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Mensaje
                Text(mensaje,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4)),

                // Ciclo estimado personalizado
                if (intervalo != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.history, size: 14, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text('Ciclo estimado de tu vehículo: ~$intervalo días',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ],

                // Problemas recurrentes
                if (recurrentes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.repeat, size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: recurrentes.map((p) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFED7AA)),
                            ),
                            child: Text(p,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                          )).toList(),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // Botón solicitar servicio
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.build_outlined, size: 18),
                    label: const Text('Solicitar servicio de mantenimiento',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onSolicitarServicio,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
