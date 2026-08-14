import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/application/media/request_photo_service.dart';
import 'package:yukitas/application/requests/snow_analysis_provider.dart';
import 'package:yukitas/domain/requests/snow_request.dart';
import 'package:yukitas/features/requester/request_creation_flow.dart';

void main() {
  testWidgets(
    'selected before photo is uploaded and stored as a Storage path',
    (tester) async {
      final imageData = await rootBundle.load(
        'assets/images/before_driveway.png',
      );
      final picker = _FakePhotoPicker(imageData.buffer.asUint8List());
      final storage = _FakePhotoStorage();
      SnowRequest? publishedRequest;

      await tester.pumpWidget(
        MaterialApp(
          home: RequestCreationFlow(
            analysisProvider: const DemoSnowAnalysisProvider(),
            photoPicker: picker,
            photoStorage: storage,
            onPublish: (request) async => publishedRequest = request,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('location-continue')));
      await tester.pumpAndSettle();
      expect(find.text('依頼を公開するには、現在の雪の写真を追加してください'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('pick-before-gallery')));
      await tester.tap(find.byKey(const Key('pick-before-gallery')));
      await tester.pumpAndSettle();
      expect(find.text('選択済み'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('analyze-request')));
      await tester.tap(find.byKey(const Key('analyze-request')));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('analysis-continue')));
      await tester.tap(find.byKey(const Key('analysis-continue')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('publish-request')));
      await tester.tap(find.byKey(const Key('publish-request')));
      await tester.pumpAndSettle();

      expect(storage.uploadCount, 1);
      expect(storage.lastKind, RequestPhotoKind.before);
      expect(
        publishedRequest?.beforeImageAsset,
        startsWith('requestMedia/${publishedRequest?.id}/before/test-user/'),
      );
    },
  );
}

class _FakePhotoPicker implements RequestPhotoPicker {
  _FakePhotoPicker(this.bytes);

  final Uint8List bytes;

  @override
  Future<PickedRequestPhoto?> pick(RequestPhotoSource source) async {
    return PickedRequestPhoto(
      bytes: bytes,
      fileName: 'snow.jpg',
      contentType: 'image/jpeg',
    );
  }

  @override
  Future<PickedRequestPhoto?> recoverPending() async => null;
}

class _FakePhotoStorage implements RequestPhotoStorage {
  int uploadCount = 0;
  RequestPhotoKind? lastKind;

  @override
  bool get usesFirebase => true;

  @override
  Future<String> upload({
    required String requestId,
    required RequestPhotoKind kind,
    required PickedRequestPhoto photo,
  }) async {
    uploadCount++;
    lastKind = kind;
    return 'requestMedia/$requestId/${kind.name}/test-user/photo.jpg';
  }

  @override
  Future<void> delete(String storagePath) async {}
}
