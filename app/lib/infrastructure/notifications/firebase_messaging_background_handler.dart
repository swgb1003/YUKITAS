import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../auth/yukitas_firebase_options.dart';

/// Runs in a separate isolate when a push arrives while the app isn't in the
/// foreground, so it needs its own Firebase init. There's nothing else to do
/// here - request-status pushes are informational only, and Android/iOS
/// already show the notification tray entry from the message's `notification`
/// payload without any app code involved.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!YukitasFirebaseOptions.isConfigured) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: YukitasFirebaseOptions.currentPlatform,
    );
  }
}
