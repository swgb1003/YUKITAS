import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/places/saved_place.dart';
import '../location/current_location.dart';
import '../theme/yukitas_colors.dart';

class PickedLocation {
  const PickedLocation({
    required this.position,
    required this.address,
    this.savedPlace,
  });

  final LatLng position;
  final String address;

  /// Set only when the point came from tapping a registered saved place
  /// (spec 03章 遠隔家族), so callers can tell that apart from a free-form
  /// map pick without comparing coordinates.
  final SavedPlace? savedPlace;
}

/// Interactive map for choosing a request's location (R-02): tap or drag the
/// pin, jump to the device's current location, or snap to one of the
/// requester's saved places. Reverse-geocodes the picked point so the
/// confirmation card can show a real address instead of a hardcoded one.
class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    required this.initialPosition,
    required this.onLocationResolved,
    super.key,
    this.savedPlaces = const <SavedPlace>[],
  });

  final LatLng initialPosition;
  final ValueChanged<PickedLocation> onLocationResolved;
  final List<SavedPlace> savedPlaces;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  late LatLng _position = widget.initialPosition;
  GoogleMapController? _controller;
  final _searchController = TextEditingController();
  bool _resolvingAddress = false;
  bool _locatingDevice = false;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _setGeocoderLocale();
    // Defer past the first frame: resolving synchronously (e.g. when the
    // geocoding plugin errors immediately) can call the ancestor's setState
    // while this widget's own subtree is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_resolveAddress(_position));
    });
  }

  /// Best-effort: not every platform implements this, and when there is no
  /// geocoder plugin registered at all (e.g. widget tests) the call throws
  /// synchronously rather than via the returned Future.
  void _setGeocoderLocale() {
    try {
      unawaited(geocoding.setLocaleIdentifier('ja_JP').catchError((_) {}));
    } catch (_) {
      // Ignore - address search will just use whatever locale the
      // platform's geocoder falls back to.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(LatLng position, {SavedPlace? source}) async {
    setState(() => _resolvingAddress = true);
    var address = source?.approximateAddress ?? '選択した地点';
    if (source == null) {
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final parts =
              [
                placemark.administrativeArea,
                placemark.locality,
                placemark.subLocality,
                placemark.thoroughfare,
              ].where((part) => part != null && part.isNotEmpty).join('');
          if (parts.isNotEmpty) address = parts;
        }
      } catch (_) {
        // Reverse geocoding can fail offline; keep the fallback label.
      }
    }
    if (!mounted) return;
    setState(() => _resolvingAddress = false);
    widget.onLocationResolved(
      PickedLocation(position: position, address: address, savedPlace: source),
    );
  }

  Future<void> _movePin(LatLng position, {SavedPlace? source}) async {
    setState(() => _position = position);
    await _resolveAddress(position, source: source);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locatingDevice = true);
    try {
      final current = await resolveCurrentPosition();
      final position = LatLng(current.latitude, current.longitude);
      await _controller?.animateCamera(CameraUpdate.newLatLng(position));
      await _movePin(position);
    } on LocationUnavailable catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _locatingDevice = false);
    }
  }

  Future<void> _useSavedPlace(SavedPlace place) async {
    final position = LatLng(place.latitude, place.longitude);
    await _controller?.animateCamera(CameraUpdate.newLatLng(position));
    await _movePin(position, source: place);
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _searching) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _searching = true);
    try {
      final locations = await geocoding.locationFromAddress(query);
      if (locations.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('住所が見つかりませんでした。もう少し詳しく入力するか、地図をタップしてください。'),
            ),
          );
        }
        return;
      }
      final position = LatLng(
        locations.first.latitude,
        locations.first.longitude,
      );
      await _controller?.animateCamera(CameraUpdate.newLatLng(position));
      await _movePin(position);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('住所を検索できませんでした。通信を確認して再度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedPlaces = widget.savedPlaces;
    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _position, zoom: 15),
          onMapCreated: (controller) => _controller = controller,
          onTap: _movePin,
          markers: {
            Marker(
              markerId: const MarkerId('picked-location'),
              position: _position,
              draggable: true,
              onDragEnd: _movePin,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
        Positioned(
          left: 14,
          right: 14,
          top: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchBar(
                controller: _searchController,
                searching: _searching,
                onSubmitted: (_) => _searchAddress(),
                onSearchPressed: _searchAddress,
              ),
              if (savedPlaces.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: savedPlaces.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final place = savedPlaces[index];
                      return _PillButton(
                        key: Key('use-saved-place-${place.id}'),
                        icon: Icons.home_outlined,
                        label: place.label,
                        onPressed: () => _useSavedPlace(place),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_resolvingAddress)
          const Positioned(
            left: 14,
            bottom: 14,
            child: _PillButton(icon: Icons.sync_rounded, label: '住所を確認中'),
          ),
        Positioned(
          right: 14,
          bottom: 14,
          child: FloatingActionButton.small(
            key: const Key('use-current-location'),
            heroTag: 'use-current-location',
            backgroundColor: Colors.white,
            foregroundColor: YukitasColors.action,
            onPressed: _locatingDevice ? null : _useCurrentLocation,
            child:
                _locatingDevice
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.searching,
    required this.onSubmitted,
    required this.onSearchPressed,
  });

  final TextEditingController controller;
  final bool searching;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: YukitasColors.outline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14075B9B),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: YukitasColors.muted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              key: const Key('location-search-field'),
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              decoration: const InputDecoration(
                hintText: '住所や建物名で検索',
                hintStyle: TextStyle(
                  color: YukitasColors.muted,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(
                color: YukitasColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (searching)
            const Padding(
              padding: EdgeInsets.all(13),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              key: const Key('location-search-button'),
              onPressed: onSearchPressed,
              icon: const Icon(Icons.arrow_forward_rounded),
              color: YukitasColors.action,
            ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    super.key,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: YukitasColors.outline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14075B9B),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: YukitasColors.action),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: YukitasColors.deep,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
    if (onPressed == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onPressed,
        child: content,
      ),
    );
  }
}
