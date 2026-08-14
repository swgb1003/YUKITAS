import 'package:flutter/foundation.dart';

import 'saved_place.dart';

abstract interface class SavedPlaceRepository implements Listenable {
  List<SavedPlace> get places;

  Future<void> add(SavedPlace place);

  Future<void> update(SavedPlace place);

  Future<void> remove(String placeId);
}
