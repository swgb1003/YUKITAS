import 'package:firebase_storage/firebase_storage.dart';

import '../../application/media/request_photo_service.dart';

class FirebaseRequestPhotoStorage implements RequestPhotoStorage {
  FirebaseRequestPhotoStorage({required this.userId, FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final String userId;
  final FirebaseStorage _storage;

  @override
  bool get usesFirebase => true;

  @override
  Future<String> upload({
    required String requestId,
    required RequestPhotoKind kind,
    required PickedRequestPhoto photo,
  }) async {
    _validatePathSegment(requestId, 'requestId');
    _validatePathSegment(userId, 'userId');
    final extension = switch (photo.contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch.toString()}.$extension';
    final path = 'requestMedia/$requestId/${kind.name}/$userId/$fileName';
    final reference = _storage.ref(path);
    try {
      await reference.putData(
        photo.bytes,
        SettableMetadata(
          contentType: photo.contentType,
          cacheControl: 'private,max-age=3600',
          customMetadata: <String, String>{
            'requestId': requestId,
            'kind': kind.name,
            'uploaderId': userId,
          },
        ),
      );
      return path;
    } on FirebaseException catch (error) {
      throw RequestPhotoFailure(_messageFor(error));
    }
  }

  @override
  Future<void> delete(String storagePath) async {
    if (!storagePath.startsWith('requestMedia/')) return;
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  void _validatePathSegment(String value, String name) {
    if (value.isEmpty || value.contains('/')) {
      throw ArgumentError.value(value, name, 'Invalid Storage path segment');
    }
  }

  String _messageFor(FirebaseException error) {
    return switch (error.code) {
      'unauthenticated' => '写真を保存するには、もう一度ログインしてください。',
      'unauthorized' => 'この写真を保存する権限がありません。',
      'quota-exceeded' => '写真の保存容量を確認してください。',
      'retry-limit-exceeded' => '通信が安定してから、もう一度お試しください。',
      'bucket-not-found' ||
      'no-default-bucket' => '写真保存のFirebase設定がまだ完了していません。',
      _ => '写真を保存できませんでした。通信を確認して再度お試しください。',
    };
  }
}
