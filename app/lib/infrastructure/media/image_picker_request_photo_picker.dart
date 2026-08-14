import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../application/media/request_photo_service.dart';

class ImagePickerRequestPhotoPicker implements RequestPhotoPicker {
  ImagePickerRequestPhotoPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  static const _maxBytes = 10 * 1024 * 1024;
  static const _allowedContentTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  final ImagePicker _imagePicker;

  @override
  Future<PickedRequestPhoto?> pick(RequestPhotoSource source) async {
    final image = await _imagePicker.pickImage(
      source:
          source == RequestPhotoSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 86,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    return _toRequestPhoto(image);
  }

  @override
  Future<PickedRequestPhoto?> recoverPending() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) return null;
    final image = response.file ?? response.files?.lastOrNull;
    if (image == null) {
      throw const RequestPhotoFailure('撮影した写真を復元できませんでした。もう一度撮影してください。');
    }
    return _toRequestPhoto(image);
  }

  Future<PickedRequestPhoto> _toRequestPhoto(XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw const RequestPhotoFailure('画像データを読み込めませんでした。');
    }
    if (bytes.length > _maxBytes) {
      throw const RequestPhotoFailure('写真は10MB以下にしてください。');
    }

    final contentType =
        image.mimeType ?? lookupMimeType(image.name, headerBytes: bytes);
    if (contentType == null || !_allowedContentTypes.contains(contentType)) {
      throw const RequestPhotoFailure('JPEG、PNG、WebP形式の写真を選んでください。');
    }
    return PickedRequestPhoto(
      bytes: bytes,
      fileName: image.name,
      contentType: contentType,
    );
  }
}
