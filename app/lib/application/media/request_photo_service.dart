import 'dart:typed_data';

enum RequestPhotoSource { camera, gallery }

enum RequestPhotoKind { before, after }

class PickedRequestPhoto {
  const PickedRequestPhoto({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

class RequestPhotoFailure implements Exception {
  const RequestPhotoFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class RequestPhotoPicker {
  Future<PickedRequestPhoto?> pick(RequestPhotoSource source);

  Future<PickedRequestPhoto?> recoverPending();
}

abstract interface class RequestPhotoStorage {
  bool get usesFirebase;

  Future<String> upload({
    required String requestId,
    required RequestPhotoKind kind,
    required PickedRequestPhoto photo,
  });

  Future<void> delete(String storagePath);
}

class DemoRequestPhotoStorage implements RequestPhotoStorage {
  const DemoRequestPhotoStorage();

  @override
  bool get usesFirebase => false;

  @override
  Future<String> upload({
    required String requestId,
    required RequestPhotoKind kind,
    required PickedRequestPhoto photo,
  }) async {
    return kind == RequestPhotoKind.before
        ? 'assets/images/before_driveway.png'
        : 'assets/images/after_driveway.png';
  }

  @override
  Future<void> delete(String storagePath) async {}
}
