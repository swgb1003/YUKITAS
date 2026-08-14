import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/requests/snow_request.dart';
import '../formatters/yukitas_formatters.dart';
import '../theme/yukitas_colors.dart';

/// Niigata city center. Used whenever there are no requests to frame the
/// camera around, matching the contest demo's fixed location.
const niigataCenter = LatLng(37.9161, 139.0364);

/// Real Google Map showing snow-removal requests as color-coded markers:
/// red = waiting, orange = matched/in progress, green = completed, and a
/// rose marker for SOS requests regardless of status (spec 06 章).
class SnowMap extends StatelessWidget {
  const SnowMap({
    super.key,
    this.compact = false,
    this.requests = const <SnowRequest>[],
    this.center,
    this.onTapRequest,
    this.interactive = true,
  });

  final bool compact;
  final List<SnowRequest> requests;
  final LatLng? center;
  final ValueChanged<SnowRequest>? onTapRequest;
  final bool interactive;

  LatLng get _resolvedCenter {
    final fixedCenter = center;
    if (fixedCenter != null) return fixedCenter;
    if (requests.isEmpty) return niigataCenter;
    final avgLat =
        requests.map((r) => r.latitude).reduce((a, b) => a + b) /
        requests.length;
    final avgLng =
        requests.map((r) => r.longitude).reduce((a, b) => a + b) /
        requests.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '除雪依頼マップ。${requests.length}件の依頼を表示',
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _resolvedCenter,
          zoom: compact ? 12.4 : 13.6,
        ),
        markers: requests.map(_markerFor).toSet(),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: !compact,
        mapToolbarEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        scrollGesturesEnabled: interactive,
        zoomGesturesEnabled: interactive,
      ),
    );
  }

  Marker _markerFor(SnowRequest request) {
    final hue = switch (request) {
      _ when request.isSos => BitmapDescriptor.hueRose,
      _ when request.status == RequestStatus.waiting =>
        BitmapDescriptor.hueRed,
      _ when request.status == RequestStatus.completed =>
        BitmapDescriptor.hueGreen,
      _ => BitmapDescriptor.hueOrange,
    };
    return Marker(
      markerId: MarkerId(request.id),
      position: LatLng(request.latitude, request.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(
        title:
            request.isSos ? 'SOS • ${request.workTitle}' : request.workTitle,
        snippet: '${formatYen(request.priceYen)} • ${request.status.workerLabel}',
      ),
      onTap: onTapRequest == null ? null : () => onTapRequest!(request),
    );
  }
}

/// Small colored dot used by map legends to explain marker colors.
class SnowMapLegendDot extends StatelessWidget {
  const SnowMapLegendDot({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

const snowMapWaitingColor = YukitasColors.sos;
const snowMapActiveColor = YukitasColors.warm;
const snowMapCompleteColor = YukitasColors.safe;
const snowMapSosColor = Color(0xFFE0338F);
