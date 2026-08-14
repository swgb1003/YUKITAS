import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/places/saved_place.dart';

class SavedPlaceFirestoreCodec {
  const SavedPlaceFirestoreCodec._();

  static Map<String, Object?> encode(SavedPlace place, {Object? updatedAt}) {
    return <String, Object?>{
      'label': place.label,
      'approximateAddress': place.approximateAddress,
      'location': GeoPoint(place.latitude, place.longitude),
      'beneficiaryName': place.beneficiaryName,
      'notifyOnSnowfall': place.notifyOnSnowfall,
      'updatedAt': updatedAt ?? Timestamp.now(),
    };
  }

  static SavedPlace decode(String id, Map<String, dynamic> data) {
    final location = data['location'];
    if (location is! GeoPoint) {
      throw const FormatException('location must be a GeoPoint');
    }
    final label = data['label'];
    if (label is! String || label.isEmpty) {
      throw const FormatException('label must be a non-empty string');
    }
    final approximateAddress = data['approximateAddress'];
    if (approximateAddress is! String || approximateAddress.isEmpty) {
      throw const FormatException('approximateAddress must be a non-empty string');
    }

    return SavedPlace(
      id: id,
      label: label,
      approximateAddress: approximateAddress,
      latitude: location.latitude,
      longitude: location.longitude,
      beneficiaryName: data['beneficiaryName'] as String?,
      notifyOnSnowfall: data['notifyOnSnowfall'] as bool? ?? true,
    );
  }
}
