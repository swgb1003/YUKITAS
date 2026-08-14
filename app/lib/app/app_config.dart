enum AppFlavor { development, demo, production }

class AppConfig {
  const AppConfig._();

  static const String _flavorName = String.fromEnvironment(
    'YUKITAS_FLAVOR',
    defaultValue: 'demo',
  );

  static AppFlavor get flavor => switch (_flavorName) {
    'development' => AppFlavor.development,
    'production' => AppFlavor.production,
    _ => AppFlavor.demo,
  };

  static bool get showsDemoTools => flavor != AppFlavor.production;

  static const bool firebaseStorageEnabled = bool.fromEnvironment(
    'YUKITAS_STORAGE_ENABLED',
    defaultValue: true,
  );

  /// Whether to call the `analyzeSnowPhoto` Cloud Function for AI image
  /// analysis. Separate from [firebaseStorageEnabled] so Storage can be
  /// turned on before the Cloud Function is deployed - the app falls back
  /// to [DemoSnowAnalysisProvider] while this is false.
  static const bool cloudAiEnabled = bool.fromEnvironment(
    'YUKITAS_AI_ENABLED',
    defaultValue: true,
  );
}
