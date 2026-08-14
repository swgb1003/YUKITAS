import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../application/auth/auth_service.dart';
import '../application/media/request_photo_service.dart';
import '../application/notifications/push_notification_service.dart';
import '../application/requests/snow_analysis_provider.dart';
import '../core/theme/yukitas_theme.dart';
import '../features/auth/login_screen.dart';
import '../features/splash/splash_screen.dart';
import '../infrastructure/media/firebase_request_photo_storage.dart';
import '../infrastructure/media/image_picker_request_photo_picker.dart';
import '../infrastructure/notifications/firebase_push_notification_service.dart';
import '../infrastructure/places/firestore_saved_place_repository.dart';
import '../infrastructure/requests/cloud_function_snow_analysis_provider.dart';
import '../infrastructure/requests/firestore_request_repository.dart';
import 'app_config.dart';
import 'app_routes.dart';
import 'mode_shell.dart';

class YukitasApp extends StatelessWidget {
  const YukitasApp({super.key, this.authService});

  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    final effectiveAuthService = authService ?? DemoAuthService();
    return MaterialApp(
      title: 'YUKITAS',
      debugShowCheckedModeBanner: false,
      theme: YukitasTheme.light,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash:
            (_) => SplashScreen(
              nextRoute:
                  effectiveAuthService.currentUser == null
                      ? AppRoutes.login
                      : AppRoutes.home,
            ),
        AppRoutes.login:
            (context) => LoginScreen(
              authService: effectiveAuthService,
              onAuthenticated:
                  () => Navigator.of(
                    context,
                  ).pushReplacementNamed(AppRoutes.home),
            ),
        AppRoutes.home: (context) {
          final user = effectiveAuthService.currentUser;
          if (effectiveAuthService.usesFirebase && user != null) {
            final displayName = user.displayName?.trim();
            final photoPicker =
                AppConfig.firebaseStorageEnabled
                    ? ImagePickerRequestPhotoPicker()
                    : null;
            final RequestPhotoStorage photoStorage =
                AppConfig.firebaseStorageEnabled
                    ? FirebaseRequestPhotoStorage(userId: user.id)
                    : const DemoRequestPhotoStorage();
            final SnowAnalysisProvider analysisProvider =
                AppConfig.cloudAiEnabled
                    ? CloudFunctionSnowAnalysisProvider()
                    : const DemoSnowAnalysisProvider();
            final PushNotificationService pushNotificationService =
                FirebasePushNotificationService(userId: user.id);
            return ModeShell(
              repository: FirestoreRequestRepository(userId: user.id),
              disposeRepository: true,
              savedPlaceRepository: FirestoreSavedPlaceRepository(
                userId: user.id,
              ),
              disposeSavedPlaceRepository: true,
              pushNotificationService: pushNotificationService,
              disposePushNotificationService: true,
              currentUserId: user.id,
              currentUserName:
                  displayName == null || displayName.isEmpty
                      ? 'YUKITASワーカー'
                      : displayName,
              photoPicker: photoPicker,
              photoStorage: photoStorage,
              analysisProvider: analysisProvider,
              onSignOut: () async {
                final navigator = Navigator.of(context);
                await effectiveAuthService.signOut();
                await navigator.pushNamedAndRemoveUntil(
                  AppRoutes.login,
                  (route) => false,
                );
              },
            );
          }
          return const ModeShell();
        },
      },
    );
  }
}
