import 'package:geolocator/geolocator.dart';

class LocationUnavailable implements Exception {
  const LocationUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolves the device's current position, requesting permission if needed.
///
/// Throws [LocationUnavailable] when permission is denied or location
/// services are off, so callers can fall back to a demo position instead of
/// blocking the flow (matches the spec's "demo tolerance" requirement).
Future<Position> resolveCurrentPosition() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw const LocationUnavailable('位置情報サービスが無効になっています');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const LocationUnavailable('位置情報の利用が許可されていません');
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}
