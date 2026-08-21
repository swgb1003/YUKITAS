import 'dart:math' as math;

/// Geohash helpers used to publish a *coarse* location for open requests
/// (spec 06.1 "個人宅の正確な位置は受注前に公開せず、地図上では丸めた座標
/// またはエリア表示にする") and to scope nearby-request queries to a region
/// (spec 08.3), replacing the previous global "all waiting requests" fetch.
///
/// Keep this in sync with `functions/src/geo.ts`, which computes the same
/// values server-side when projecting a request onto the public board.
const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Precision of the coordinate published to every signed-in user. A level-6
/// cell is roughly 1.2km x 0.6km, so snapping to its center keeps the real
/// address inside a block of hundreds of homes - enough to show regional
/// activity without letting anyone navigate to a specific house.
const publicLocationPrecision = 6;

/// Precision of the cell requests are bucketed into for querying. A level-5
/// cell is roughly 4.9km square; querying it plus its 8 neighbours covers
/// about 15km across, which is the useful radius for snow removal.
const boardCellPrecision = 5;

String encodeGeohash(
  double latitude,
  double longitude, {
  int precision = publicLocationPrecision,
}) {
  var latMin = -90.0;
  var latMax = 90.0;
  var lngMin = -180.0;
  var lngMax = 180.0;
  final buffer = StringBuffer();
  var evenBit = true;
  var bit = 0;
  var index = 0;

  while (buffer.length < precision) {
    if (evenBit) {
      final mid = (lngMin + lngMax) / 2;
      if (longitude >= mid) {
        index = index * 2 + 1;
        lngMin = mid;
      } else {
        index = index * 2;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (latitude >= mid) {
        index = index * 2 + 1;
        latMin = mid;
      } else {
        index = index * 2;
        latMax = mid;
      }
    }
    evenBit = !evenBit;
    if (++bit == 5) {
      buffer.write(_base32[index]);
      bit = 0;
      index = 0;
    }
  }
  return buffer.toString();
}

class GeoBounds {
  const GeoBounds({
    required this.latMin,
    required this.latMax,
    required this.lngMin,
    required this.lngMax,
  });

  final double latMin;
  final double latMax;
  final double lngMin;
  final double lngMax;

  double get centerLatitude => (latMin + latMax) / 2;
  double get centerLongitude => (lngMin + lngMax) / 2;
}

GeoBounds decodeGeohashBounds(String geohash) {
  var latMin = -90.0;
  var latMax = 90.0;
  var lngMin = -180.0;
  var lngMax = 180.0;
  var evenBit = true;

  for (final char in geohash.split('')) {
    final index = _base32.indexOf(char);
    if (index < 0) {
      throw FormatException('Invalid geohash character: $char');
    }
    for (var mask = 16; mask > 0; mask >>= 1) {
      if (evenBit) {
        final mid = (lngMin + lngMax) / 2;
        if (index & mask != 0) {
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (index & mask != 0) {
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      evenBit = !evenBit;
    }
  }
  return GeoBounds(
    latMin: latMin,
    latMax: latMax,
    lngMin: lngMin,
    lngMax: lngMax,
  );
}

/// The cell's center point - the coordinate that stands in for the real
/// address on the public board.
({double latitude, double longitude}) geohashCenter(String geohash) {
  final bounds = decodeGeohashBounds(geohash);
  return (
    latitude: bounds.centerLatitude,
    longitude: bounds.centerLongitude,
  );
}

/// The cell containing [geohash] plus its 8 surrounding cells, so a worker
/// standing near a cell border still sees requests just across it.
///
/// Derived by re-encoding points offset by one cell width/height from the
/// center rather than walking base-32 border tables - same result, far less
/// that can go subtly wrong at the edges.
List<String> geohashNeighbours(String geohash) {
  final bounds = decodeGeohashBounds(geohash);
  final latSpan = bounds.latMax - bounds.latMin;
  final lngSpan = bounds.lngMax - bounds.lngMin;
  final cells = <String>{};

  for (final latOffset in <double>[-latSpan, 0, latSpan]) {
    for (final lngOffset in <double>[-lngSpan, 0, lngSpan]) {
      final latitude = (bounds.centerLatitude + latOffset).clamp(-90.0, 90.0);
      var longitude = bounds.centerLongitude + lngOffset;
      if (longitude > 180) longitude -= 360;
      if (longitude < -180) longitude += 360;
      cells.add(encodeGeohash(latitude, longitude, precision: geohash.length));
    }
  }
  return cells.toList()..sort();
}

const _earthRadiusKm = 6371.0;

/// Great-circle distance in kilometres. Distance is a relation between a
/// worker and a request, so it is computed here from the worker's own
/// position - it is never stored on the request (the previous model kept a
/// fixed `distanceKm` on the document, which showed every worker the same
/// number no matter where they were).
double distanceKmBetween(
  double fromLatitude,
  double fromLongitude,
  double toLatitude,
  double toLongitude,
) {
  final dLat = _toRadians(toLatitude - fromLatitude);
  final dLng = _toRadians(toLongitude - fromLongitude);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(fromLatitude)) *
          math.cos(_toRadians(toLatitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return _earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
