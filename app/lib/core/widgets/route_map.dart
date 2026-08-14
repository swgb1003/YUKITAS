import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../location/current_location.dart';
import '../theme/yukitas_colors.dart';

/// Real map showing a worker's route to a request's destination as two
/// markers connected by a straight polyline ("簡易更新でも可" per spec 04章).
/// Falls back to a nearby demo origin point when the device's location is
/// unavailable, so the screen still demonstrates the flow.
class RouteMap extends StatefulWidget {
  const RouteMap({required this.destination, super.key, this.requesterView = false});

  final LatLng destination;
  final bool requesterView;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  GoogleMapController? _controller;
  LatLng? _origin;
  bool _usingDemoOrigin = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveOrigin());
  }

  Future<void> _resolveOrigin() async {
    try {
      final position = await resolveCurrentPosition();
      if (!mounted) return;
      setState(() {
        _origin = LatLng(position.latitude, position.longitude);
        _usingDemoOrigin = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _origin = LatLng(
          widget.destination.latitude - 0.006,
          widget.destination.longitude - 0.008,
        );
        _usingDemoOrigin = true;
      });
    }
    _fitBounds();
  }

  void _fitBounds() {
    final controller = _controller;
    final origin = _origin;
    if (controller == null || origin == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(origin.latitude, widget.destination.latitude),
        math.min(origin.longitude, widget.destination.longitude),
      ),
      northeast: LatLng(
        math.max(origin.latitude, widget.destination.latitude),
        math.max(origin.longitude, widget.destination.longitude),
      ),
    );
    unawaited(controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80)));
  }

  @override
  Widget build(BuildContext context) {
    final origin = _origin;
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.destination,
            zoom: 14,
          ),
          onMapCreated: (controller) {
            _controller = controller;
            _fitBounds();
          },
          markers: {
            Marker(
              markerId: const MarkerId('destination'),
              position: widget.destination,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              infoWindow: const InfoWindow(title: '依頼場所'),
            ),
            if (origin != null)
              Marker(
                markerId: const MarkerId('origin'),
                position: origin,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
                infoWindow: InfoWindow(
                  title: widget.requesterView ? 'ワーカーの現在地' : '現在地',
                ),
              ),
          },
          polylines:
              origin == null
                  ? const {}
                  : {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: [origin, widget.destination],
                      color: YukitasColors.worker,
                      width: 5,
                    ),
                  },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
        if (_usingDemoOrigin)
          Positioned(
            left: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xDFFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: YukitasColors.outline),
              ),
              child: const Text(
                '現在地はデモ表示です',
                style: TextStyle(
                  color: YukitasColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
