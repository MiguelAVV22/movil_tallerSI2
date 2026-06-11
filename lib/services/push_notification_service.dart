import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:taller_movil/features/comunicacion/chat/chat_page.dart';

// Top-level function for background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background message received: ${message.messageId}");
}

class PushNotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static String? fcmToken;

  static Future<void> inicializar() async {
    try {
      // Inicializar Firebase
      await Firebase.initializeApp();

      // Configurar handler de segundo plano
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Solicitar permisos de notificaciones push
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Permisos de notificaciones: ${settings.authorizationStatus}');

      // Obtener el Token FCM
      fcmToken = await messaging.getToken();
      debugPrint('FCM Token obtenido: $fcmToken');

      // Escuchar cambios de token
      messaging.onTokenRefresh.listen((newToken) {
        fcmToken = newToken;
        debugPrint('FCM Token actualizado: $fcmToken');
      });

      // Configurar listeners de interacción con notificaciones
      _configurarInteracciones();
    } catch (e) {
      debugPrint('Error al inicializar FCM: $e');
    }
  }

  static void _configurarInteracciones() {
    // 1. Cuando la app está en primer plano (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Mensaje recibido en primer plano: ${message.notification?.title}');
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted && message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${message.notification!.title}: ${message.notification!.body}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF051D72),
            action: SnackBarAction(
              label: 'Ver',
              textColor: Colors.white,
              onPressed: () {
                _manejarRedireccion(message.data);
              },
            ),
          ),
        );
      }
    });

    // 2. Cuando la app está en segundo plano y el usuario toca la notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notificación abierta desde segundo plano: ${message.data}');
      _manejarRedireccion(message.data);
    });

    // 3. Cuando la app estaba cerrada por completo y se abre desde una notificación
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('Notificación abrió la app desde estado apagado: ${message.data}');
        Future.delayed(const Duration(seconds: 1), () {
          _manejarRedireccion(message.data);
        });
      }
    });
  }

  static void _manejarRedireccion(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final screen = data['screen']?.toString();
    if (screen == '/comunicacion/chat') {
      final asignacionIdStr = data['asignacion_id']?.toString();
      final nombreContacto = data['nombreContacto']?.toString() ?? 'Chat';
      if (asignacionIdStr != null) {
        final asignacionId = int.tryParse(asignacionIdStr);
        if (asignacionId != null) {
          Navigator.pushNamed(
            context,
            '/comunicacion/chat',
            arguments: ChatArgs(
              asignacionId: asignacionId,
              nombreContacto: nombreContacto,
            ),
          );
        }
      }
    } else if (screen == '/seguimiento') {
      final incidenteIdStr = data['incidente_id']?.toString();
      if (incidenteIdStr != null) {
        final incidenteId = int.tryParse(incidenteIdStr);
        if (incidenteId != null) {
          Navigator.pushNamed(
            context,
            '/seguimiento',
            arguments: incidenteId,
          );
        }
      }
    }
  }
}
