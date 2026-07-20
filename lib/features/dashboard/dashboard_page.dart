import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/auth_service.dart';
import 'package:taller_movil/services/notificacion_service.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/emergencia_local_service.dart';
import 'package:taller_movil/services/sync_service.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/services/sos_service.dart';
import 'package:taller_movil/shared/app_drawer.dart';
import 'dart:async';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _authService = AuthService();
  final _notifService = NotificacionService();
  Map<String, dynamic>? _user;
  int _notifsNoLeidas = 0;
  Timer? _notifPoll;

  int _pendientesSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _cargarNotifNoLeidas();
    _actualizarPendientesSync();
    _notifPoll = Timer.periodic(const Duration(seconds: 20), (_) => _cargarNotifNoLeidas());
    
    // Escuchar el servicio de sincronización para actualizar el contador automáticamente
    SyncService().estaSincronizando.addListener(_onSyncStatusChange);
  }

  @override
  void dispose() {
    _notifPoll?.cancel();
    SyncService().estaSincronizando.removeListener(_onSyncStatusChange);
    super.dispose();
  }

  void _onSyncStatusChange() {
    if (!SyncService().estaSincronizando.value) {
      _actualizarPendientesSync();
    }
  }

  Future<void> _actualizarPendientesSync() async {
    try {
      final pendientes = await EmergenciaLocalService.obtenerPendientesSync();
      if (mounted) {
        setState(() {
          _pendientesSyncCount = pendientes.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUser() async {
    final user = await _authService.getUser();
    setState(() => _user = user);
  }

  Future<void> _cargarNotifNoLeidas() async {
    try {
      final rows = await _notifService.listarMias();
      if (!mounted) return;
      setState(() => _notifsNoLeidas = rows.where((x) => x['leida'] != true).length);
    } catch (_) {}
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _mostrarDialogoSOS(BuildContext ctx) async {
    final confirmar = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
          SizedBox(width: 10),
          Text('Botón SOS', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          '¿Confirmas el envío de una alerta de emergencia urgente?\n\n'
          'Se enviará tu ubicación GPS y se alertará a todos los talleres disponibles.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Enviar SOS', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    // Obtener GPS — funciona con satélites, no requiere datos móviles
    double? lat, lng;
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
        ).timeout(const Duration(seconds: 10));
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {
      // GPS no disponible — el SOS se envía igual, visible para talleres aunque sin coordenadas
    }

    try {
      await EmergenciaService().enviarSOS(latitud: lat, longitud: lng);
      if (!mounted) return;
      final msg = lat != null
          ? '🆘 SOS enviado con tu ubicación. Talleres alertados.'
          : '🆘 SOS enviado sin GPS. Talleres alertados.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.danger, duration: const Duration(seconds: 4)),
      );

      // Alertar familiares / Contactos SOS configurados
      try {
        final sosSvc = SosService();
        final contactos = await sosSvc.listarContactos();
        if (contactos.isNotEmpty && mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.share, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text('Alertar a Familiares', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SOS enviado exitosamente en la plataforma.'),
                  const SizedBox(height: 8),
                  const Text(
                    '¿Deseas enviar una alerta directa de emergencia a tus contactos de confianza por WhatsApp?',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),
                  ...contactos.map((cont) {
                    final String nombre = cont['nombre'] ?? '';
                    final String relacion = cont['relacion'] ?? 'contacto';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: const Color(0xFFF9FAFB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.chat, color: Colors.white, size: 18),
                        ),
                        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(relacion, style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () async {
                          Navigator.pop(c);
                          await sosSvc.dispararSOS(cont, usarWhatsapp: true);
                        },
                      ),
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Omitir', style: TextStyle(color: Color(0xFF9CA3AF))),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        print('[SOS] Error cargando contactos de emergencia: $e');
      }

      if (mounted) {
        Navigator.pushNamed(context, '/solicitudes/estado');
      }
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger),
      );
    }
  }

  String get _userName    => _user?['full_name'] ?? _user?['username'] ?? 'Usuario';
  String get _role        => _user?['role'] as String? ?? 'cliente';
  bool   get _isAdmin     => _role == 'admin';
  bool   get _isTaller    => _role == 'taller';
  bool   get _isTecnico   => _role == 'tecnico';
  bool   get _isCliente   => _role == 'cliente';

  String get _roleLabel {
    switch (_role) {
      case 'admin':   return 'Administrador';
      case 'taller':  return 'Taller';
      case 'tecnico': return 'Técnico';
      default:        return 'Cliente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bienvenida
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bienvenido,', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_roleLabel,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),

            if (_isCliente && _pendientesSyncCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_queue_rounded, color: Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tienes $_pendientesSyncCount ${_pendientesSyncCount == 1 ? 'reporte' : 'reportes'} de emergencia pendiente(s) de envío.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/emergencias/sync-progress');
                        _actualizarPendientesSync();
                      },
                      child: Text(
                        'Ver Progreso',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // SOS Button — visible solo para clientes
            if (_isCliente) ...[
              const SizedBox(height: 24),
              _SosButton(onTap: () => _mostrarDialogoSOS(context)),
            ],

            const SizedBox(height: 28),

            // Accesos rápidos
            const Text('ACCESOS RÁPIDOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.8)),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _quickCards(context),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _quickCards(BuildContext ctx) {
    if (_isCliente) {
      return [
        _QuickCard(icon: Icons.warning_amber_outlined,   label: 'Reportar Emergencia', iconBg: const Color(0xFFFEF2F2), iconColor: AppColors.danger,   onTap: () => Navigator.pushNamed(ctx, '/emergencias/reportar')),
        _QuickCard(icon: Icons.directions_car,           label: 'Mis Vehículos',       iconBg: const Color(0xFFEFF6FF), iconColor: AppColors.primary,  onTap: () => Navigator.pushNamed(ctx, '/acceso/mis-vehiculos')),
        _QuickCard(icon: Icons.track_changes_outlined,   label: 'Mis Solicitudes',     iconBg: const Color(0xFFEFF6FF), iconColor: AppColors.primary,  onTap: () => Navigator.pushNamed(ctx, '/solicitudes/estado')),
        _QuickCard(icon: Icons.history,                  label: 'Historial',           iconBg: const Color(0xFFF5F3FF), iconColor: const Color(0xFF7C3AED), onTap: () => Navigator.pushNamed(ctx, '/cliente/historial')),
        _QuickCard(icon: Icons.chat_bubble_outline,      label: 'Chat',                iconBg: const Color(0xFFECFDF5), iconColor: AppColors.success,  onTap: () => Navigator.pushNamed(ctx, '/comunicacion/chat')),
      ];
    }
    if (_isTaller) {
      return [
        _QuickCard(icon: Icons.assignment_outlined,      label: 'Ver Solicitudes',     iconBg: const Color(0xFFEFF6FF), iconColor: AppColors.primary,  onTap: () => Navigator.pushNamed(ctx, '/solicitudes/disponibles')),
        _QuickCard(icon: Icons.build_outlined,           label: 'Estado Servicio',     iconBg: const Color(0xFFFEF2F2), iconColor: AppColors.danger,   onTap: () => Navigator.pushNamed(ctx, '/talleres/estado-servicio')),
        _QuickCard(icon: Icons.people_outline,           label: 'Técnicos',            iconBg: const Color(0xFFECFDF5), iconColor: AppColors.success,  onTap: () => Navigator.pushNamed(ctx, '/talleres/tecnicos')),
        _QuickCard(icon: Icons.chat_bubble_outline,      label: 'Chat',                iconBg: const Color(0xFFECFDF5), iconColor: AppColors.success,  onTap: () => Navigator.pushNamed(ctx, '/comunicacion/chat')),
        _QuickCard(icon: Icons.receipt_long_outlined,    label: 'Cotizaciones',        iconBg: const Color(0xFFF5F3FF), iconColor: const Color(0xFF7C3AED), onTap: () => Navigator.pushNamed(ctx, '/pagos/cotizacion')),
        _QuickCard(icon: Icons.toggle_on_outlined,       label: 'Disponibilidad',      iconBg: const Color(0xFFFFF7ED), iconColor: const Color(0xFFD97706), onTap: () => Navigator.pushNamed(ctx, '/talleres/disponibilidad')),
      ];
    }
    if (_isTecnico) {
      return [
        _QuickCard(icon: Icons.build_outlined,           label: 'Estado Servicio',     iconBg: const Color(0xFFEFF6FF), iconColor: AppColors.primary,  onTap: () => Navigator.pushNamed(ctx, '/talleres/estado-servicio')),
        _QuickCard(icon: Icons.chat_bubble_outline,      label: 'Chat',                iconBg: const Color(0xFFECFDF5), iconColor: AppColors.success,  onTap: () => Navigator.pushNamed(ctx, '/comunicacion/chat')),
        _QuickCard(icon: Icons.task_alt,                 label: 'Registrar Servicio',  iconBg: const Color(0xFFFEF2F2), iconColor: AppColors.danger,   onTap: () => Navigator.pushNamed(ctx, '/talleres/registrar-servicio')),
        _QuickCard(icon: Icons.location_on_outlined,     label: 'Compartir Ubicación', iconBg: const Color(0xFFECFDF5), iconColor: AppColors.success,  onTap: () => Navigator.pushNamed(ctx, '/comunicacion/compartir-ubicacion')),
      ];
    }
    if (_isAdmin) {
      return [
        _QuickCard(icon: Icons.verified_outlined,        label: 'Aprobar Talleres',    iconBg: const Color(0xFFECFDF5), iconColor: AppColors.success,  onTap: () => Navigator.pushNamed(ctx, '/acceso/aprobar-talleres')),
        _QuickCard(icon: Icons.manage_accounts_outlined, label: 'Gestionar Usuarios',  iconBg: const Color(0xFFEFF6FF), iconColor: AppColors.primary,  onTap: () => Navigator.pushNamed(ctx, '/acceso/gestionar-usuarios')),
        _QuickCard(icon: Icons.policy_outlined,          label: 'Auditoría',           iconBg: const Color(0xFFFEF2F2), iconColor: AppColors.danger,   onTap: () => Navigator.pushNamed(ctx, '/reportes/auditoria')),
        _QuickCard(icon: Icons.bar_chart_outlined,       label: 'Comisiones',          iconBg: const Color(0xFFF5F3FF), iconColor: const Color(0xFF7C3AED), onTap: () => Navigator.pushNamed(ctx, '/pagos/comisiones')),
      ];
    }
    return [];
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFF3F4F6), height: 1),
      ),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, color: AppColors.text),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.route, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          const Text('RutaSegura', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text)),
        ],
      ),
      actions: [
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, size: 22),
              if (_notifsNoLeidas > 0)
                Positioned(
                  top: -5,
                  right: -7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF2B2D),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _notifsNoLeidas > 99 ? '99+' : '$_notifsNoLeidas',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Notificaciones',
          onPressed: () async {
            await Navigator.pushNamed(context, '/comunicacion/notificaciones');
            if (mounted) _cargarNotifNoLeidas();
          },
          color: const Color(0xFF6B7280),
        ),
        IconButton(
          icon: const Icon(Icons.logout_outlined, size: 20),
          tooltip: 'Cerrar sesión',
          onPressed: _logout,
          color: const Color(0xFF6B7280),
        ),
      ],
    );
  }
}

// ── SOS Button ────────────────────────────────────────────────
class _SosButton extends StatelessWidget {
  const _SosButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.danger.withValues(alpha: 0.35),
              blurRadius: 16, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sos, color: Colors.white, size: 32),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('BOTÓN SOS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                Text('Emergencia urgente — toca para activar',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Card ────────────────────────────────────────────────
class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color iconBg, iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF3F4F6)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 10),
              Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
            ],
          ),
        ),
      ),
    );
  }
}
