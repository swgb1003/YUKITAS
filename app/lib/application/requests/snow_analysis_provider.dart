class SnowAnalysisResult {
  const SnowAnalysisResult({
    required this.snowDepthCm,
    required this.areaSqm,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.confidence,
    required this.hazards,
  });

  final int snowDepthCm;
  final double areaSqm;
  final int difficulty;
  final int estimatedMinutes;
  final double confidence;
  final List<String> hazards;
}

/// Thrown by a [SnowAnalysisProvider] when analysis could not complete
/// (timeout, backend error, invalid AI response, ...). [message] is safe to
/// show directly to the requester.
class SnowAnalysisFailure implements Exception {
  const SnowAnalysisFailure(this.message, {this.isTimeout = false});

  final String message;
  final bool isTimeout;

  @override
  String toString() => message;
}

abstract interface class SnowAnalysisProvider {
  /// [imageReference] is either a bundled asset path (demo data) or a
  /// Firebase Storage path the caller has already uploaded the photo to -
  /// providers that need real bytes (e.g. calling a Vision AI backend)
  /// fetch them from Storage using this path.
  Future<SnowAnalysisResult> analyze({
    required String imageReference,
    required double selectedAreaSqm,
    required List<String> workAreas,
  });
}

class DemoSnowAnalysisProvider implements SnowAnalysisProvider {
  const DemoSnowAnalysisProvider();

  @override
  Future<SnowAnalysisResult> analyze({
    required String imageReference,
    required double selectedAreaSqm,
    required List<String> workAreas,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 720));
    return SnowAnalysisResult(
      snowDepthCm: 28,
      areaSqm: selectedAreaSqm,
      difficulty: 3,
      estimatedMinutes: 45,
      confidence: 0.78,
      hazards: const ['門扉付近に段差あり', '雪の吹きだまり'],
    );
  }
}
