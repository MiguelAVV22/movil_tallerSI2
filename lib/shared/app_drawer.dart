import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/auth_service.dart';

// Modelos internos para nav declarativo
class _ItemDef {
  final String label;
  final String route;
  final List<String> roles;
  const _ItemDef({required this.label, required this.route, required this.roles});
  bool canAccess(String role) => roles.isEmpty || roles.contains(role);
}

class _SectionDef {
  final String id;
  final IconData icon;
  final String label;
  final List<_ItemDef> items;
  final Color? iconColor;
  const _SectionDef({
    required this.id,
    required this.icon,
    required this.label,
    required this.items,
    this.iconColor,
  });
  bool hasAnyAccess(String role) => items.any((i) => i.canAccess(role));
}

// ── Los 7 módulos siempre visibles ───────────────────────────
final _allSections = [
  _SectionDef(
    id: 'acceso',
    icon: Icons.manage_accounts_outlined,
    label: 'Acceso y Registro',
    items: [
      _ItemDef(label: 'Mis Vehículos',      route: '/acceso/mis-vehiculos',    roles: ['cliente']),
      _ItemDef(label: 'Registrar Taller',   route: '/acceso/registrar-taller', roles: ['taller']),
      _ItemDef(label: 'Gestionar Usuarios', route: '/gestionar-usuarios',      roles: ['admin']),
      _ItemDef(label: 'Aprobar Talleres',   route: '/aprobar-talleres',        roles: ['admin']),
    ],
  ),
  _SectionDef(
    id: 'emergencias',
    icon: Icons.warning_amber_rounded,
    label: 'Emergencias',
    iconColor: AppColors.danger,
    items: [
      _ItemDef(label: 'Reportar Emergencia',   route: '/emergencias/reportar',    roles: ['cliente']),
      _ItemDef(label: 'Enviar Audio',          route: '/emergencias/audio',       roles: ['cliente']),
      _ItemDef(label: 'Agregar Descripción',   route: '/emergencias/descripcion', roles: ['cliente']),
    ],
  ),
  _SectionDef(
    id: 'solicitudes',
    icon: Icons.assignment_outlined,
    label: 'Solicitudes',
    items: [
      _ItemDef(label: 'Ver Estado',              route: '/solicitudes/estado',       roles: ['cliente']),
      _ItemDef(label: 'Cancelar Solicitud',      route: '/solicitudes/cancelar',     roles: ['cliente']),
      _ItemDef(label: 'Ver Disponibles',         route: '/solicitudes/disponibles',  roles: ['taller']),
      _ItemDef(label: 'Detalle de Incidente',    route: '/solicitudes/detalle',      roles: ['taller']),
      _ItemDef(label: 'Aceptar Solicitud',       route: '/solicitudes/aceptar',      roles: ['taller']),
      _ItemDef(label: 'Rechazar Solicitud',      route: '/solicitudes/rechazar',     roles: ['taller']),
    ],
  ),
  _SectionDef(
    id: 'talleres',
    icon: Icons.build_outlined,
    label: 'Talleres y Técnicos',
    items: [
      _ItemDef(label: 'Gestionar Técnicos',       route: '/talleres/gestionar-tecnicos',  roles: ['taller']),
      _ItemDef(label: 'Gestionar Disponibilidad', route: '/talleres/disponibilidad',       roles: ['taller']),
      _ItemDef(label: 'Actualizar Estado Servicio', route: '/talleres/estado-servicio',   roles: ['taller', 'tecnico']),
      _ItemDef(label: 'Registrar Servicio',       route: '/talleres/servicio-realizado',  roles: ['taller', 'tecnico']),
    ],
  ),
  _SectionDef(
    id: 'pagos',
    icon: Icons.payments_outlined,
    label: 'Cotización y Pagos',
    items: [
      _ItemDef(label: 'Generar Cotización',   route: '/pagos/generar',     roles: ['taller']),
      _ItemDef(label: 'Ver Cotizaciones',     route: '/pagos/ver',         roles: ['taller', 'cliente']),
      _ItemDef(label: 'Confirmar Cotización', route: '/pagos/confirmar',   roles: ['taller']),
      _ItemDef(label: 'Realizar Pago',        route: '/pagos/realizar',    roles: ['cliente']),
      _ItemDef(label: 'Ver Comisiones',       route: '/pagos/comisiones',  roles: ['taller']),
    ],
  ),
  _SectionDef(
    id: 'comunicacion',
    icon: Icons.chat_bubble_outline,
    label: 'Comunicación',
    items: [
      _ItemDef(label: 'Chat',             route: '/comunicacion/chat',           roles: ['cliente', 'taller', 'tecnico']),
      _ItemDef(label: 'Notificaciones',   route: '/comunicacion/notificaciones', roles: ['cliente', 'taller']),
      _ItemDef(label: 'Ver Técnico en Mapa', route: '/comunicacion/ver-tecnico', roles: ['cliente']),
      _ItemDef(label: 'Compartir Ubicación', route: '/comunicacion/compartir-ubicacion', roles: ['tecnico']),
    ],
  ),
  _SectionDef(
    id: 'reportes',
    icon: Icons.bar_chart_outlined,
    label: 'Reportes',
    items: [
      _ItemDef(label: 'Historial de Servicios', route: '/reportes/historial',         roles: ['cliente', 'taller']),
      _ItemDef(label: 'Calificar Servicio',     route: '/reportes/calificar',         roles: ['cliente']),
      _ItemDef(label: 'Recordatorios',          route: '/mantenimiento/recordatorios', roles: ['cliente']),
      _ItemDef(label: 'Métricas del Taller',    route: '/reportes/metricas-taller',   roles: ['taller']),
      _ItemDef(label: 'Métricas Globales',      route: '/reportes/metricas-globales', roles: ['admin']),
      _ItemDef(label: 'Auditoría / Bitácora',   route: '/reportes/auditoria',         roles: ['admin']),
    ],
  ),
];

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _auth = AuthService();
  Map<String, dynamic>? _user;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _auth.getUser().then((u) => setState(() => _user = u));
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _navigate(String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }

  void _navigateDenied() {
    Navigator.pop(context);
    Navigator.pushNamed(context, '/acceso-denegado');
  }

  void _toggle(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  String get _roleLabel {
    final r = _user?['role'] as String? ?? 'cliente';
    const map = {
      'admin': 'Administrador',
      'taller': 'Taller',
      'tecnico': 'Técnico',
      'cliente': 'Cliente',
    };
    return map[r] ?? r;
  }

  @override
  Widget build(BuildContext context) {
    final name    = _user?['full_name'] ?? _user?['username'] ?? '...';
    final email   = _user?['email'] ?? '';
    final role    = _user?['role'] as String? ?? 'cliente';
    final initial = name.isNotEmpty ? (name as String)[0].toUpperCase() : '?';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // ── Cabecera ─────────────────────────────────────
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            accountName: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            accountEmail: Row(
              children: [
                Flexible(
                  child: Text(email, style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _roleLabel,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // ── Ítems de navegación ──────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Dashboard
                ListTile(
                  leading: const Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 22),
                  title: const Text('Inicio',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text)),
                  horizontalTitleGap: 8,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (r) => false);
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),

                // ── 7 módulos siempre visibles ───────────────
                ...(_allSections.map<Widget>((section) {
                  final sectionLocked = !section.hasAnyAccess(role);
                  final isOpen = _expanded.contains(section.id);

                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          section.icon,
                          color: sectionLocked
                              ? AppColors.grey
                              : (section.iconColor ?? AppColors.primary),
                          size: 22,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                section.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: sectionLocked ? AppColors.grey : AppColors.text,
                                ),
                              ),
                            ),
                            if (sectionLocked)
                              const Icon(Icons.lock_outline, size: 14, color: AppColors.grey),
                          ],
                        ),
                        trailing: AnimatedRotation(
                          turns: isOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.expand_more, color: AppColors.grey, size: 20),
                        ),
                        horizontalTitleGap: 8,
                        onTap: () => _toggle(section.id),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Container(
                          color: const Color(0xFFF9FAFB),
                          child: Column(
                            children: section.items.map((item) {
                              final itemLocked = !item.canAccess(role);
                              return ListTile(
                                contentPadding: const EdgeInsets.only(left: 56, right: 16),
                                dense: true,
                                leading: itemLocked
                                    ? const Icon(Icons.lock_outline, size: 13, color: AppColors.grey)
                                    : null,
                                title: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: itemLocked ? AppColors.grey : AppColors.text,
                                  ),
                                ),
                                onTap: itemLocked
                                    ? _navigateDenied
                                    : () => _navigate(item.route),
                              );
                            }).toList(),
                          ),
                        ),
                        crossFadeState: isOpen
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  );
                })),

                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Pie con acciones ─────────────────────────────
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.key_outlined, color: AppColors.primary, size: 22),
            title: const Text(
              'Cambiar contraseña',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/acceso/cambiar-contrasena');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger, size: 22),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            onTap: _logout,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
