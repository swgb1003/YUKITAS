import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/requests/request_summary.dart';
import '../../domain/requests/snow_request.dart';
import '../formatters/yukitas_formatters.dart';
import '../theme/yukitas_colors.dart';

/// Niigata city center. Used whenever there are no requests to frame the
/// camera around, matching the contest demo's fixed location.
const niigataCenter = LatLng(37.9161, 139.0364);

/// One marker on the snow map.
///
/// The map takes pins rather than requests so that where a coordinate came
/// from stays the caller's decision. Someone else's request can only ever be
/// pinned at the cell center published on the board
/// ([MapPin.fromSummary]); a request pinned at its real address
/// ([MapPin.fromRequest]) is one the viewer already owns or has been
/// assigned. Handing this widget a request list is what previously plotted
/// strangers' front doors on a public map.
class MapPin {
  const MapPin({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.snippet,
    required this.isSos,
    required this.status,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String snippet;
  final bool isSos;
  final RequestStatus status;

  /// Pins a request at its exact location. Only valid for a request the
  /// viewer is a party to.
  factory MapPin.fromRequest(SnowRequest request) => MapPin(
    id: request.id,
    latitude: request.latitude,
    longitude: request.longitude,
    title: request.isSos ? 'SOS • ${request.workTitle}' : request.workTitle,
    snippet:
        '${formatYen(request.priceYen)} • ${request.status.workerLabel}',
    isSos: request.isSos,
    status: request.status,
  );

  /// Pins a request at its published cell center - roughly a kilometre of
  /// blur, so the marker shows where work is happening without showing whose
  /// house it is.
  factory MapPin.fromSummary(RequestSummary summary) => MapPin(
    id: summary.id,
    latitude: summary.coarseLatitude,
    longitude: summary.coarseLongitude,
    title: summary.isSos ? 'SOS • ${summary.workTitle}' : summary.workTitle,
    snippet:
        '${formatYen(summary.priceYen)} • ${summary.status.workerLabel}',
    isSos: summary.isSos,
    status: summary.status,
  );
}

/// Real Google Map showing snow-removal requests as color-coded markers:
/// red = waiting, orange = matched/in progress, green = completed, and a
/// rose marker for SOS requests regardless of status (spec 06 章).
class SnowMap extends StatelessWidget {
  const SnowMap({
    super.key,
    this.compact = false,
    this.pins = const <MapPin>[],
    this.center,
    this.onTapPin,
    this.interactive = true,
  });

  final bool compact;
  final List<MapPin> pins;
  final LatLng? center;
  final ValueChanged<String>? onTapPin;
  final bool interactive;

  LatLng get _resolvedCenter {
    final fixedCenter = center;
    if (fixedCenter != null) return fixedCenter;
    if (pins.isEmpty) return niigataCenter;
    final avgLat =
        pins.map((p) => p.latitude).reduce((a, b) => a + b) / pins.length;
    final avgLng =
        pins.map((p) => p.longitude).reduce((a, b) => a + b) / pins.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '除雪依頼マップ。${pins.length}件の依頼を表示',
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _resolvedCenter,
          zoom: compact ? 12.4 : 13.6,
        ),
        markers: pins.map(_markerFor).toSet(),
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

  Marker _markerFor(MapPin pin) {
    final hue = switch (pin) {
      _ when pin.isSos => BitmapDescriptor.hueRose,
      _ when pin.status == RequestStatus.waiting => BitmapDescriptor.hueRed,
      _ when pin.status == RequestStatus.completed =>
        BitmapDescriptor.hueGreen,
      _ => BitmapDescriptor.hueOrange,
    };
    return Marker(
      markerId: MarkerId(pin.id),
      position: LatLng(pin.latitude, pin.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(title: pin.title, snippet: pin.snippet),
      onTap: onTapPin == null ? null : () => onTapPin!(pin.id),
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
