import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase identifiers for the YUKITAS project.
///
/// Firebase client identifiers are not secrets. Each value can still be
/// overridden with `--dart-define` when an environment-specific project is
/// introduced later.
class YukitasFirebaseOptions {
  const YukitasFirebaseOptions._();

  static const _apiKey = String.fromEnvironment(
    'YUKITAS_FIREBASE_API_KEY',
    defaultValue: 'AIzaSyBziMnLwuhI2HD2f1HV9ysuM5SPcD6-WzU',
  );
  static const _androidApiKey = String.fromEnvironment(
    'YUKITAS_FIREBASE_ANDROID_API_KEY',
    defaultValue: 'AIzaSyA5NV7qcvp3Mk2iwqw9LDUG82oSWff9MR4',
  );
  static const _projectId = String.fromEnvironment(
    'YUKITAS_FIREBASE_PROJECT_ID',
    defaultValue: 'yukitas-app',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'YUKITAS_FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '652126797744',
  );
  static const _appId = String.fromEnvironment('YUKITAS_FIREBASE_APP_ID');
  static const _webAppId = String.fromEnvironment(
    'YUKITAS_FIREBASE_WEB_APP_ID',
    defaultValue: '1:652126797744:web:58285f4e061c7a9728e075',
  );
  static const _androidAppId = String.fromEnvironment(
    'YUKITAS_FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:652126797744:android:251849c7f54da07128e075',
  );
  static const _iosAppId = String.fromEnvironment(
    'YUKITAS_FIREBASE_IOS_APP_ID',
  );
  static const _authDomain = String.fromEnvironment(
    'YUKITAS_FIREBASE_AUTH_DOMAIN',
    defaultValue: 'yukitas-app.firebaseapp.com',
  );
  static const _storageBucket = String.fromEnvironment(
    'YUKITAS_FIREBASE_STORAGE_BUCKET',
    defaultValue: 'yukitas-app.firebasestorage.app',
  );
  static const _measurementId = String.fromEnvironment(
    'YUKITAS_FIREBASE_MEASUREMENT_ID',
  );
  static const _webClientId = String.fromEnvironment(
    'YUKITAS_FIREBASE_WEB_CLIENT_ID',
    defaultValue:
        '652126797744-cjn02942tutruqhjvc7irlkuv20m26b3.apps.googleusercontent.com',
  );
  static const _iosClientId = String.fromEnvironment(
    'YUKITAS_FIREBASE_IOS_CLIENT_ID',
  );

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _projectId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      _currentAppId.isNotEmpty;

  static String? get webClientId => _nullIfEmpty(_webClientId);

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError('YUKITAS用のFirebase設定がありません。');
    }
    return FirebaseOptions(
      apiKey:
          !kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android &&
                  _androidApiKey.isNotEmpty
              ? _androidApiKey
              : _apiKey,
      appId: _currentAppId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      authDomain: _nullIfEmpty(_authDomain),
      storageBucket: _nullIfEmpty(_storageBucket),
      measurementId: kIsWeb ? _nullIfEmpty(_measurementId) : null,
      iosClientId: _nullIfEmpty(_iosClientId),
      androidClientId: _nullIfEmpty(_webClientId),
      iosBundleId: 'jp.yukitas.yukitas',
    );
  }

  static String get _currentAppId {
    if (kIsWeb) return _webAppId.isNotEmpty ? _webAppId : _appId;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        _androidAppId.isNotEmpty ? _androidAppId : _appId,
      TargetPlatform.iOS ||
      TargetPlatform.macOS => _iosAppId.isNotEmpty ? _iosAppId : _appId,
      _ => _appId,
    };
  }

  static String? _nullIfEmpty(String value) => value.isEmpty ? null : value;
}
