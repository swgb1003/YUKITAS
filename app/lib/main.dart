import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'app/yukitas_app.dart';
import 'infrastructure/auth/auth_bootstrap.dart';
import 'infrastructure/notifications/firebase_messaging_background_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = await AuthBootstrap.initialize();
  if (authService.usesFirebase) {
    // Best-effort: platforms without a firebase_messaging implementation
    // (desktop) throw here, and push notifications just stay unavailable.
    try {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
    } catch (_) {}
  }
  runApp(YukitasApp(authService: authService));
}
