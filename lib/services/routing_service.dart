import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> points;

  RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });
}

const String orsApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjE3OTU1ZDdkZTgxZTRlNzRhNTlmYTNiY2I0YzVjY2QwIiwiaCI6Im11cm11cjY0In0=';

class RoutingService {

  Future<RouteResult?> obtenerRuta({
    required double origenLat,
    required double origenLng,
    required double destinoLat,
    required double destinoLng,
  }) async {
    // 1. Intentar primero con OpenRouteService
    try {
      final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=$origenLng,$origenLat&end=$destinoLng,$destinoLat',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      
      // Códigos específicos de fallback solicitados (o cualquier error de ORS)
      final fallbackCodes = [401, 403, 429, 500, 502, 503, 504];
      if (fallbackCodes.contains(response.statusCode) || response.statusCode != 200) {
        // Ejecutar fallback inmediato a OSRM
        return await _obtenerRutaOSRM(origenLat, origenLng, destinoLat, destinoLng);
      }

      final data = jsonDecode(response.body);
      final features = data['features'] as List?;
      if (features != null && features.isNotEmpty) {
        final firstFeature = features[0] as Map<String, dynamic>;
        final geometry = firstFeature['geometry'] as Map<String, dynamic>;
        final coordinates = geometry['coordinates'] as List;
        final properties = firstFeature['properties'] as Map<String, dynamic>;
        final summary = properties['summary'] as Map<String, dynamic>;

        final distance = (summary['distance'] as num).toDouble();
        final duration = (summary['duration'] as num).toDouble();

        final points = coordinates.map((coord) {
          final pointList = coord as List;
          final lng = (pointList[0] as num).toDouble();
          final lat = (pointList[1] as num).toDouble();
          return LatLng(lat, lng);
        }).toList();

        return RouteResult(
          distanceMeters: distance,
          durationSeconds: duration,
          points: points,
        );
      }
    } catch (e) {
      // Ante cualquier excepción de red, timeout o error inesperado, ejecutar fallback
      return await _obtenerRutaOSRM(origenLat, origenLng, destinoLat, destinoLng);
    }
    return null;
  }

  // 2. Método de Fallback usando OSRM (Gratuito, sin clave)
  Future<RouteResult?> _obtenerRutaOSRM(
    double origenLat,
    double origenLng,
    double destinoLat,
    double destinoLng,
  ) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$origenLng,$origenLat;$destinoLng,$destinoLat?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }
      final data = jsonDecode(response.body);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        return null;
      }
      final firstRoute = routes[0] as Map<String, dynamic>;
      final distance = (firstRoute['distance'] as num).toDouble();
      final duration = (firstRoute['duration'] as num).toDouble();
      final geometry = firstRoute['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List;

      final points = coordinates.map((coord) {
        final pointList = coord as List;
        final lng = (pointList[0] as num).toDouble();
        final lat = (pointList[1] as num).toDouble();
        return LatLng(lat, lng);
      }).toList();

      return RouteResult(
        distanceMeters: distance,
        durationSeconds: duration,
        points: points,
      );
    } catch (e) {
      return null;
    }
  }
}
