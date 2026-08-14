import 'package:flutter/foundation.dart';

import '../../domain/places/saved_place.dart';
import '../../domain/places/saved_place_repository.dart';

class InMemorySavedPlaceRepository extends ChangeNotifier
    implements SavedPlaceRepository {
  InMemorySavedPlaceRepository({List<SavedPlace>? seedPlaces})
    : _places = [...(seedPlaces ?? _defaultPlaces)];

  static const _defaultPlaces = [
    SavedPlace(
      id: 'demo-place-niigata-home',
      label: '新潟の実家',
      approximateAddress: '新潟市中央区',
      latitude: 37.9161,
      longitude: 139.0364,
      beneficiaryName: 'お母さま',
    ),
  ];

  final List<SavedPlace> _places;

  @override
  List<SavedPlace> get places => List.unmodifiable(_places);

  @override
  Future<void> add(SavedPlace place) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _places.add(place);
    notifyListeners();
  }

  @override
  Future<void> update(SavedPlace place) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _places.indexWhere((item) => item.id == place.id);
    if (index == -1) return;
    _places[index] = place;
    notifyListeners();
  }

  @override
  Future<void> remove(String placeId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _places.removeWhere((item) => item.id == placeId);
    notifyListeners();
  }
}
