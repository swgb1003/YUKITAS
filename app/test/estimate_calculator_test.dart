import 'package:flutter_test/flutter_test.dart';
import 'package:yukitas/application/requests/estimate_calculator.dart';
import 'package:yukitas/application/requests/snow_analysis_provider.dart';

void main() {
  const analysis = SnowAnalysisResult(
    snowDepthCm: 28,
    areaSqm: 18,
    difficulty: 3,
    estimatedMinutes: 45,
    confidence: 0.78,
    hazards: ['段差'],
  );

  test('calculates 基本600円 + 50円/分 + 難易度補正 with no demand surcharge', () {
    final estimate = const EstimateCalculator().calculate(analysis);

    expect(estimate.baseFeeYen, 600);
    expect(estimate.timeFeeYen, 2250);
    expect(estimate.difficultyFeeYen, 400);
    expect(estimate.demandFeeYen, 0);
    expect(estimate.totalYen, 3250);
  });

  test('adds 5% demand surcharge per nearby waiting request', () {
    final estimate = const EstimateCalculator().calculate(
      analysis,
      nearbyWaitingCount: 2,
    );

    // Subtotal 3250 * 10% = 325.
    expect(estimate.demandFeeYen, 325);
    expect(estimate.totalYen, 3575);
  });

  test('caps the demand surcharge at 30% however busy the area is', () {
    final estimate = const EstimateCalculator().calculate(
      analysis,
      nearbyWaitingCount: 50,
    );

    // Subtotal 3250 * 30% cap = 975.
    expect(estimate.demandFeeYen, 975);
    expect(estimate.totalYen, 4225);
  });
}
