import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_config.dart';
import '../../application/auth/auth_service.dart';
import 'firebase_auth_service.dart';
import 'yukitas_firebase_options.dart';

class AuthBootstrap {
  const AuthBootstrap._();

  static Future<AuthService> initialize() async {
    if (!YukitasFirebaseOptions.isConfigured) {
      if (AppConfig.flavor == AppFlavor.production) {
        throw StateError('本番ビルドにはYUKITAS用Firebase設定が必要です。');
      }
      return DemoAuthService();
    }

    try {
      await Firebase.initializeApp(
        options: YukitasFirebaseOptions.currentPlatform,
      );
      await FirebaseAuth.instance.setLanguageCode('ja');
      return FirebaseAuthService();
    } catch (error, stackTrace) {
      if (AppConfig.flavor == AppFlavor.production) rethrow;
      debugPrint('Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return DemoAuthService();
    }
  }
}
