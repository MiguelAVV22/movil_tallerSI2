import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/auth_service.dart';
import 'package:taller_movil/shared/acceso_denegado_page.dart';

// Acceso y Registro
import 'package:taller_movil/features/acceso_registro/iniciar_sesion/iniciar_sesion_page.dart';
import 'package:taller_movil/features/acceso_registro/registrarse/registrarse_page.dart';
import 'package:taller_movil/features/acceso_registro/cambiar_contrasena/cambiar_contrasena_page.dart';
import 'package:taller_movil/features/acceso_registro/recuperar_contrasena/recuperar_contrasena_page.dart';
import 'package:taller_movil/features/acceso_registro/registrar_vehiculo/registrar_vehiculo_page.dart';
import 'package:taller_movil/features/acceso_registro/gestionar_vehiculos/gestionar_vehiculos_page.dart';
import 'package:taller_movil/features/acceso_registro/registrar_taller/registrar_taller_page.dart';
import 'package:taller_movil/features/acceso_registro/aprobar_talleres/aprobar_talleres_page.dart';
import 'package:taller_movil/features/acceso_registro/gestionar_usuarios/gestionar_usuarios_page.dart';

// Dashboard
import 'package:taller_movil/features/dashboard/dashboard_page.dart';

// Emergencias
import 'package:taller_movil/features/emergencias/reportar_emergencia/reportar_emergencia_page.dart';
import 'package:taller_movil/features/emergencias/enviar_audio/enviar_audio_page.dart';
import 'package:taller_movil/features/emergencias/agregar_descripcion/agregar_descripcion_page.dart';

// Solicitudes
import 'package:taller_movil/features/solicitudes/ver_estado_solicitud/ver_estado_solicitud_page.dart';
import 'package:taller_movil/features/solicitudes/cancelar_solicitud/cancelar_solicitud_page.dart';
import 'package:taller_movil/features/solicitudes/ver_solicitudes_disponibles/ver_solicitudes_disponibles_page.dart';
import 'package:taller_movil/features/solicitudes/ver_detalle_incidente/ver_detalle_incidente_page.dart';
import 'package:taller_movil/features/solicitudes/aceptar_solicitud/aceptar_solicitud_page.dart';
import 'package:taller_movil/features/solicitudes/rechazar_solicitud/rechazar_solicitud_page.dart';

// Talleres y Técnicos
import 'package:taller_movil/features/talleres_tecnicos/gestionar_tecnicos/gestionar_tecnicos_page.dart';
import 'package:taller_movil/features/talleres_tecnicos/gestionar_disponibilidad/gestionar_disponibilidad_page.dart';
import 'package:taller_movil/features/talleres_tecnicos/actualizar_estado_servicio/actualizar_estado_servicio_page.dart';
import 'package:taller_movil/features/talleres_tecnicos/registrar_servicio_realizado/registrar_servicio_realizado_page.dart';

// Cotización y Pagos
import 'package:taller_movil/features/cotizacion_pagos/generar_cotizacion/generar_cotizacion_page.dart';
import 'package:taller_movil/features/cotizacion_pagos/ver_cotizacion/ver_cotizacion_page.dart';
import 'package:taller_movil/features/cotizacion_pagos/confirmar_cotizacion/confirmar_cotizacion_page.dart';
import 'package:taller_movil/features/cotizacion_pagos/realizar_pago/realizar_pago_page.dart';
import 'package:taller_movil/features/cotizacion_pagos/ver_comisiones/ver_comisiones_page.dart';

// Comunicación
import 'package:taller_movil/features/comunicacion/chat/chat_page.dart';
import 'package:taller_movil/features/comunicacion/notificaciones/notificaciones_page.dart';
import 'package:taller_movil/features/comunicacion/ver_tecnico_mapa/ver_tecnico_mapa_page.dart';
import 'package:taller_movil/features/comunicacion/compartir_ubicacion/compartir_ubicacion_page.dart';

// Reportes
import 'package:taller_movil/features/reportes/historial_servicios/historial_servicios_page.dart';
import 'package:taller_movil/features/reportes/calificar_servicio/calificar_servicio_page.dart';
import 'package:taller_movil/features/reportes/recordatorios_mantenimiento/recordatorios_mantenimiento_page.dart';
import 'package:taller_movil/features/reportes/metricas_taller/metricas_taller_page.dart';
import 'package:taller_movil/features/reportes/metricas_globales/metricas_globales_page.dart';
import 'package:taller_movil/features/reportes/auditoria/auditoria_page.dart';

void main() {
  runApp(const RutaSegura());
}

class RutaSegura extends StatelessWidget {
  const RutaSegura({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RutaSegura',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const _SplashRouter(),
      routes: {
        // ── Auth ──────────────────────────────────────────
        '/login':                    (_) => const IniciarSesionPage(),
        '/registro':                 (_) => const RegistrarsePage(),
        '/recuperar-contrasena':     (_) => const RecuperarContrasenaPage(),
        '/dashboard':                (_) => const DashboardPage(),
        '/acceso/cambiar-contrasena': (_) => const CambiarContrasenaPage(),

        // ── Pantalla de acceso denegado ───────────────────
        '/acceso-denegado': (_) => const AccesoDenegadoPage(),

        // ── Acceso y Registro ─────────────────────────────
        '/acceso/registrar-vehiculo': (_) => const RegistrarVehiculoPage(),
        '/acceso/mis-vehiculos':      (_) => const GestionarVehiculosPage(),
        '/acceso/registrar-taller':   (_) => const RegistrarTallerPage(),
        '/aprobar-talleres':          (_) => const AprobarTalleresPage(),
        '/gestionar-usuarios':        (_) => const GestionarUsuariosPage(),

        // ── Emergencias ───────────────────────────────────
        '/emergencias/reportar':     (_) => const ReportarEmergenciaPage(),
        '/emergencias/audio':        (ctx) => EnviarAudioPage(
                                     incidenteId: (ModalRoute.of(ctx)?.settings.arguments as int?) ?? 0),
        '/emergencias/descripcion':  (_) => const AgregarDescripcionPage(),
        // ubicacion y fotos se navegan desde ReportarEmergencia (requieren incidenteId)

        // ── Solicitudes ───────────────────────────────────
        '/solicitudes/estado':       (_) => const VerEstadoSolicitudPage(),
        '/solicitudes/cancelar':     (_) => const CancelarSolicitudPage(),
        '/solicitudes/disponibles':  (_) => const VerSolicitudesDisponiblesPage(),
        '/solicitudes/detalle':      (_) => const VerDetalleIncidentePage(),
        '/solicitudes/aceptar':      (_) => const AceptarSolicitudPage(),
        '/solicitudes/rechazar':     (_) => const RechazarSolicitudPage(),

        // ── Talleres y Técnicos ───────────────────────────
        '/talleres/gestionar-tecnicos':  (_) => const GestionarTecnicosPage(),
        '/talleres/disponibilidad':      (_) => const GestionarDisponibilidadPage(),
        '/talleres/estado-servicio':     (_) => const ActualizarEstadoServicioPage(),
        '/talleres/servicio-realizado':  (_) => const RegistrarServicioRealizadoPage(),

        // ── Cotización y Pagos ────────────────────────────
        '/pagos/generar':    (_) => const GenerarCotizacionPage(),
        '/pagos/ver':        (_) => const VerCotizacionPage(),
        '/pagos/confirmar':  (_) => const ConfirmarCotizacionPage(),
        '/pagos/realizar':   (_) => const RealizarPagoPage(),
        '/pagos/comisiones': (_) => const VerComisionesPage(),

        // ── Comunicación ──────────────────────────────────
        '/comunicacion/chat':                  (_) => const ChatPage(),
        '/comunicacion/notificaciones':        (_) => const NotificacionesPage(),
        '/comunicacion/ver-tecnico':           (_) => const VerTecnicoMapaPage(),
        '/comunicacion/compartir-ubicacion':   (_) => const CompartirUbicacionPage(),

        // ── Reportes ──────────────────────────────────────
        '/reportes/historial':          (_) => const HistorialServiciosPage(),
        '/reportes/calificar':          (_) => const CalificarServicioPage(),
        '/mantenimiento/recordatorios': (_) => const RecordatoriosMantenimientoPage(),
        '/reportes/metricas-taller':    (_) => const MetricasTallerPage(),
        '/reportes/metricas-globales':  (_) => const MetricasGlobalesPage(),
        '/reportes/auditoria':          (_) => const AuditoriaPage(),
      },
    );
  }
}

// ── Splash Router ────────────────────────────────────────────
class _SplashRouter extends StatelessWidget {
  const _SplashRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        return snapshot.data! ? const DashboardPage() : const IniciarSesionPage();
      },
    );
  }
}
