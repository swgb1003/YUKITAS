import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/application/requests/estimate_calculator.dart';
import 'package:yukitas/application/requests/snow_analysis_provider.dart';

void main() {
  test('calculates the documented 3,200 yen demo estimate', () {
    const analysis = SnowAnalysisResult(
      snowDepthCm: 28,
      areaSqm: 18,
      difficulty: 3,
      estimatedMinutes: 45,
      confidence: 0.78,
      hazards: ['段差'],
    );

    final estimate = const EstimateCalculator().calculate(analysis);

    expect(estimate.baseFeeYen, 1000);
    expect(estimate.timeFeeYen, 1800);
    expect(estimate.difficultyFeeYen, 400);
    expect(estimate.totalYen, 3200);
  });
}
