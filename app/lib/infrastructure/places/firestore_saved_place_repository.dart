import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/places/saved_place.dart';
import '../../domain/places/saved_place_repository.dart';
import 'saved_place_firestore_codec.dart';

class FirestoreSavedPlaceRepository extends ChangeNotifier
    implements SavedPlaceRepository {
  FirestoreSavedPlaceRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance {
    _subscription = _collection.orderBy('label').snapshots().listen(
      _onSnapshot,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Firestore saved place sync failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  final String userId;
  final FirebaseFirestore _firestore;
  final List<SavedPlace> _places = <SavedPlace>[];
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _subscription;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('users')
      .doc(userId)
      .collection('savedPlaces');

  @override
  List<SavedPlace> get places => List<SavedPlace>.unmodifiable(_places);

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _places.clear();
    for (final document in snapshot.docs) {
      try {
        _places.add(SavedPlaceFirestoreCodec.decode(document.id, document.data()));
      } on FormatException catch (error) {
        debugPrint('Skipped invalid saved place ${document.id}: $error');
      }
    }
    notifyListeners();
  }

  @override
  Future<void> add(SavedPlace place) async {
    final data = SavedPlaceFirestoreCodec.encode(place);
    data['createdAt'] = FieldValue.serverTimestamp();
    await _collection.doc(place.id).set(data);
  }

  @override
  Future<void> update(SavedPlace place) async {
    await _collection.doc(place.id).update(SavedPlaceFirestoreCodec.encode(place));
  }

  @override
  Future<void> remove(String placeId) async {
    await _collection.doc(placeId).delete();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
