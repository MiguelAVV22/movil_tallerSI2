class PermissionsConfig {
  // ruta → roles que tienen acceso
  static const Map<String, List<String>> routeRoles = {
    // Acceso y Registro
    '/acceso/mis-vehiculos':     ['cliente'],
    '/acceso/registrar-taller':  ['taller'],
    '/gestionar-usuarios':       ['admin'],
    '/aprobar-talleres':         ['admin'],

    // Emergencias
    '/emergencias/reportar':     ['cliente'],
    '/emergencias/ubicacion':    ['cliente'],
    '/emergencias/fotos':        ['cliente'],
    '/emergencias/audio':        ['cliente'],
    '/emergencias/descripcion':  ['cliente'],

    // Solicitudes
    '/solicitudes/estado':       ['cliente'],
    '/solicitudes/cancelar':     ['cliente'],
    '/solicitudes/disponibles':  ['taller'],
    '/solicitudes/detalle':      ['taller'],
    '/solicitudes/aceptar':      ['taller'],
    '/solicitudes/rechazar':     ['taller'],

    // Talleres y Técnicos
    '/talleres/gestionar-tecnicos':     ['taller'],
    '/talleres/disponibilidad':         ['taller'],
    '/talleres/estado-servicio':        ['taller', 'tecnico'],
    '/talleres/servicio-realizado':     ['taller', 'tecnico'],

    // Cotización y Pagos
    '/pagos/generar':            ['taller'],
    '/pagos/ver':                ['taller', 'cliente'],
    '/pagos/confirmar':          ['taller'],
    '/pagos/realizar':           ['cliente'],
    '/pagos/comisiones':         ['taller'],

    // Comunicación
    '/comunicacion/chat':        ['cliente', 'taller', 'tecnico'],
    '/comunicacion/notificaciones': ['cliente', 'taller'],
    '/comunicacion/ver-tecnico': ['cliente'],
    '/comunicacion/compartir-ubicacion': ['tecnico'],

    // Reportes
    '/reportes/historial':       ['cliente', 'taller'],
    '/reportes/calificar':       ['cliente'],
    '/reportes/metricas-taller': ['taller'],
    '/reportes/metricas-globales': ['admin'],
    '/reportes/auditoria':       ['admin'],

    // Mantenimiento
    '/mantenimiento/recordatorios': ['cliente'],
  };

  static bool canAccess(String route, String role) {
    final allowed = routeRoles[route];
    if (allowed == null) return true;
    return allowed.contains(role);
  }
}
