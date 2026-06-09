import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/emergencia_local_service.dart';
import 'package:taller_movil/services/sync_service.dart';

class SyncProgressPage extends StatefulWidget {
  const SyncProgressPage({super.key});

  @override
  State<SyncProgressPage> createState() => _SyncProgressPageState();
}

class _SyncProgressPageState extends State<SyncProgressPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _syncService = SyncService();

  List<Map<String, dynamic>> _locales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarLocales();

    // Recargar la lista local cuando cambie el estado de sincronización
    _syncService.estaSincronizando.addListener(_onSyncStateChange);
  }

  @override
  void dispose() {
    _syncService.estaSincronizando.removeListener(_onSyncStateChange);
    _tabController.dispose();
    super.dispose();
  }

  void _onSyncStateChange() {
    if (!mounted) return;
    // Si terminó de sincronizar (estaSincronizando pasa de true a false), recargar
    if (!_syncService.estaSincronizando.value) {
      _cargarLocales();
    }
  }

  Future<void> _cargarLocales() async {
    setState(() => _isLoading = true);
    try {
      final todas = await EmergenciaLocalService.obtenerEmergenciasLocales();
      if (!mounted) return;
      setState(() {
        _locales = todas;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ejecutarSincronizacionManual() async {
    await _syncService.sincronizarPendientes();
    _cargarLocales();
  }

  @override
  Widget build(BuildContext context) {
    // Clasificar listas
    final pendientes = _locales.where((e) => e['estado_sync'] == 'PENDIENTE').toList();
    final sincronizadas = _locales.where((e) => e['estado_sync'] == 'SINCRONIZADO').toList();
    final errores = _locales.where((e) => e['estado_sync'] == 'ERROR').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Sincronización de Emergencias', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar lista',
            onPressed: _cargarLocales,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Resumen superior (Tarjetas de estado)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStateCard(
                          label: 'Pendientes',
                          count: pendientes.length,
                          color: Colors.orange,
                          bgColor: Colors.orange.shade50,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStateCard(
                          label: 'Sincronizadas',
                          count: sincronizadas.length,
                          color: AppColors.success,
                          bgColor: Colors.green.shade50,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStateCard(
                          label: 'Con Error',
                          count: errores.length,
                          color: AppColors.danger,
                          bgColor: Colors.red.shade50,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs para segmentar listas
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.grey,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Pendientes'),
                    Tab(text: 'Sincronizadas'),
                    Tab(text: 'Errores'),
                  ],
                ),

                // Contenido de cada Tab
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEmergencyList(pendientes, Colors.orange, 'No hay emergencias pendientes'),
                      _buildEmergencyList(sincronizadas, AppColors.success, 'No hay emergencias sincronizadas'),
                      _buildEmergencyList(errores, AppColors.danger, 'No hay emergencias con error'),
                    ],
                  ),
                ),

                // Consola / Logs en tiempo real
                _buildLogsConsole(),

                // Botón manual de sincronización
                _buildSyncButton(),
              ],
            ),
    );
  }

  Widget _buildStateCard({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyList(List<Map<String, dynamic>> list, Color themeColor, String emptyMessage) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, color: AppColors.grey.withValues(alpha: 0.5), size: 48),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: const TextStyle(fontSize: 14, color: AppColors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final item = list[idx];
        final bool isSync = item['estado_sync'] == 'SINCRONIZADO';
        final bool isError = item['estado_sync'] == 'ERROR';

        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prioridad: ${item['prioridad'].toString().toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getPrioridadColor(item['prioridad'] as String),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item['estado_sync'].toString(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: themeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Vehículo ID: ${item['vehiculo_id']}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
                if (item['descripcion'] != null && item['descripcion'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item['descripcion'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.grey),
                  ),
                ],
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Creado: ${_formatDate(item['fecha_creacion_local'] as String)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.grey),
                    ),
                  ],
                ),
                if (isSync) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.cloud_done_outlined, size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Backend ID: #${item['backend_incidente_id']} · ${_formatDate(item['fecha_sincronizacion'] as String)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                if (item['intentos_sync'] != null && (item['intentos_sync'] as int) > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.sync_problem, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        'Intentos: ${item['intentos_sync']}',
                        style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                if (isError && item['error_sync'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      'Error: ${item['error_sync']}',
                      style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogsConsole() {
    return Container(
      width: double.infinity,
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Logs de Sincronización',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _syncService.estaSincronizando,
                builder: (context, syncing, _) {
                  if (!syncing) return const SizedBox();
                  return const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                  );
                },
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _syncService.logsSincronizacion,
              builder: (context, logs, _) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay logs de ejecuciones recientes',
                      style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  );
                }

                // Autoscroll al final en el listview
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Pequeño retardo o scroll directo
                });

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  itemBuilder: (c, idx) {
                    final log = logs[idx];
                    Color logColor = Colors.white70;
                    if (log.contains('correctamente')) {
                      logColor = Colors.greenAccent;
                    } else if (log.contains('Error') || log.contains('expirada')) {
                      logColor = Colors.redAccent;
                    } else if (log.contains('Sincronizando')) {
                      logColor = Colors.orangeAccent;
                    }
                    return Text(
                      '> $log',
                      style: TextStyle(color: logColor, fontSize: 11, fontFamily: 'monospace', height: 1.4),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: ValueListenableBuilder<bool>(
        valueListenable: _syncService.estaSincronizando,
        builder: (context, syncing, _) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: syncing ? null : _ejecutarSincronizacionManual,
              icon: syncing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                syncing ? 'Sincronizando...' : 'Sincronizar ahora',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getPrioridadColor(String prio) {
    switch (prio.toLowerCase()) {
      case 'alta':
        return AppColors.danger;
      case 'media':
        return Colors.orange;
      default:
        return AppColors.success;
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
