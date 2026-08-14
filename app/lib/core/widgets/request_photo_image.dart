import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../theme/yukitas_colors.dart';

class RequestPhotoImage extends StatefulWidget {
  const RequestPhotoImage({
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    super.key,
  });

  static const maxDownloadBytes = 10 * 1024 * 1024;

  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<RequestPhotoImage> createState() => _RequestPhotoImageState();
}

class _RequestPhotoImageState extends State<RequestPhotoImage> {
  Future<Uint8List?>? _storageBytes;

  bool get _isAsset => widget.source.startsWith('assets/');
  bool get _isNetwork =>
      widget.source.startsWith('https://') ||
      widget.source.startsWith('http://');

  @override
  void initState() {
    super.initState();
    _loadStoragePhoto();
  }

  @override
  void didUpdateWidget(covariant RequestPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _loadStoragePhoto();
  }

  void _loadStoragePhoto() {
    _storageBytes =
        _isAsset || _isNetwork
            ? null
            : FirebaseStorage.instance
                .ref(widget.source)
                .getData(RequestPhotoImage.maxDownloadBytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_isAsset) {
      return Image.asset(
        widget.source,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder:
            (_, _, _) =>
                _PhotoLoadError(width: widget.width, height: widget.height),
      );
    }
    if (_isNetwork) {
      return Image.network(
        widget.source,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder:
            (_, _, _) =>
                _PhotoLoadError(width: widget.width, height: widget.height),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _storageBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            gaplessPlayback: true,
          );
        }
        if (snapshot.hasError) {
          return _PhotoLoadError(width: widget.width, height: widget.height);
        }
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const ColoredBox(
            color: YukitasColors.ice,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }
}

class _PhotoLoadError extends StatelessWidget {
  const _PhotoLoadError({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const ColoredBox(
        color: YukitasColors.ice,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: YukitasColors.muted,
            size: 34,
          ),
        ),
      ),
    );
  }
}
