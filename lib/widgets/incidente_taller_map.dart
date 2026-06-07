import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Mapa con dos marcadores (incidente y taller) y zoom automático.
class IncidenteTallerMap extends StatefulWidget {
  const IncidenteTallerMap({
    super.key,
    required this.incidenteLat,
    required this.incidenteLng,
    required this.tallerLat,
    required this.tallerLng,
    this.height = 200,
  });

  final double incidenteLat;
  final double incidenteLng;
  final double tallerLat;
  final double tallerLng;
  final double height;

  @override
  State<IncidenteTallerMap> createState() => _IncidenteTallerMapState();
}

class _IncidenteTallerMapState extends State<IncidenteTallerMap> {
  GoogleMapController? _controller;

  void _onMapCreated(GoogleMapController c) {
    _controller = c;
    if (!kIsWeb) {
      // Web: a veces el primer frame aún no tiene tamaño; un frame extra ayuda
      Future<void>.delayed(const Duration(milliseconds: 200), _fit);
    } else {
      _fit();
    }
  }

  Future<void> _fit() async {
    if (!mounted || _controller == null) return;
    final a = LatLng(widget.incidenteLat, widget.incidenteLng);
    final b = LatLng(widget.tallerLat, widget.tallerLng);
    final sw = LatLng(
      math.min(a.latitude, b.latitude) - 0.002,
      math.min(a.longitude, b.longitude) - 0.002,
    );
    final ne = LatLng(
      math.max(a.latitude, b.latitude) + 0.002,
      math.max(a.longitude, b.longitude) + 0.002,
    );
    try {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: sw, northeast: ne),
          48.0,
        ),
      );
    } catch (_) {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            (a.latitude + b.latitude) / 2,
            (a.longitude + b.longitude) / 2,
          ),
          13,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = LatLng(widget.incidenteLat, widget.incidenteLng);
    final b = LatLng(widget.tallerLat, widget.tallerLng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: GoogleMap(
          onMapCreated: (c) {
            _onMapCreated(c);
            if (kIsWeb) {
              Future<void>.delayed(const Duration(milliseconds: 100), _fit);
            }
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (a.latitude + b.latitude) / 2,
              (a.longitude + b.longitude) / 2,
            ),
            zoom: 12,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('incidente'),
              position: a,
              infoWindow: const InfoWindow(title: 'Tu ubicación'),
            ),
            Marker(
              markerId: const MarkerId('taller'),
              position: b,
              infoWindow: const InfoWindow(title: 'Taller'),
            ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: !kIsWeb,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }
}
