import 'package:cloud_functions/cloud_functions.dart';

import '../../application/requests/snow_analysis_provider.dart';

/// Calls the `analyzeSnowPhoto` Cloud Function, which downloads the photo
/// from Storage server-side and asks Gemini Vision for a structured
/// estimate. The Gemini API key never reaches the client (spec 07章:
/// "APIキーはアプリへ埋め込まない").
class CloudFunctionSnowAnalysisProvider implements SnowAnalysisProvider {
  CloudFunctionSnowAnalysisProvider({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  final FirebaseFunctions _functions;

  @override
  Future<SnowAnalysisResult> analyze({
    required String imageReference,
    required double selectedAreaSqm,
    required List<String> workAreas,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'analyzeSnowPhoto',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final response = await callable.call<Object?>(<String, Object?>{
        'storagePath': imageReference,
        'workAreas': workAreas,
        'selectedAreaSqm': selectedAreaSqm,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      return SnowAnalysisResult(
        snowDepthCm: (data['snowDepthCm'] as num).toInt(),
        areaSqm: (data['areaSqm'] as num).toDouble(),
        difficulty: (data['difficulty'] as num).toInt(),
        estimatedMinutes: (data['estimatedMinutes'] as num).toInt(),
        confidence: (data['confidence'] as num).toDouble(),
        hazards:
            (data['hazards'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<String>()
                .toList(growable: false),
      );
    } on FirebaseFunctionsException catch (error) {
      throw SnowAnalysisFailure(
        _messageFor(error),
        isTimeout: error.code == 'deadline-exceeded',
      );
    }
  }

  String _messageFor(FirebaseFunctionsException error) {
    return switch (error.code) {
      'unauthenticated' => 'もう一度ログインしてからお試しください。',
      'deadline-exceeded' => 'AI解析がタイムアウトしました。',
      'permission-denied' => 'この写真を解析する権限がありません。',
      'not-found' => '写真が見つかりませんでした。もう一度アップロードしてください。',
      _ => 'AI解析に失敗しました。通信を確認して再度お試しください。',
    };
  }
}
