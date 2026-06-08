import 'package:geolocator/geolocator.dart';

class UbicacionService {
  Future<Position> obtenerUbicacionActual() async {
    // 1. Verificar si el servicio de ubicación está habilitado
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    // 2. Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación requerido para transmitir seguimiento.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación requerido para transmitir seguimiento.');
    }

    // 3. Obtener posición actual con alta precisión
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
  }
}
