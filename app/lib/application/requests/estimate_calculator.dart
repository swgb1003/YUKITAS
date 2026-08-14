import 'snow_analysis_provider.dart';

class RequestEstimate {
  const RequestEstimate({
    required this.baseFeeYen,
    required this.timeFeeYen,
    required this.difficultyFeeYen,
    required this.demandFeeYen,
  });

  final int baseFeeYen;
  final int timeFeeYen;
  final int difficultyFeeYen;
  final int demandFeeYen;

  int get totalYen => baseFeeYen + timeFeeYen + difficultyFeeYen + demandFeeYen;
}

class EstimateCalculator {
  const EstimateCalculator();

  static const int baseFeeYen = 600;
  static const int perMinuteYen = 50;

  /// Surge pricing: each unclaimed 依頼 waiting nearby adds 5% on top of the
  /// base+time+difficulty subtotal, capped at +30% - approximates demand the
  /// way Uber-style surge does (more unclaimed work than workers can absorb
  /// pushes the price up), without needing live worker-supply data.
  static const double _demandRatePerWaitingRequest = 0.05;
  static const double _maxDemandRatio = 0.30;

  RequestEstimate calculate(
    SnowAnalysisResult analysis, {
    int nearbyWaitingCount = 0,
  }) {
    final difficultyFee = switch (analysis.difficulty) {
      <= 1 => 0,
      2 => 300,
      3 => 400,
      4 => 800,
      _ => 1200,
    };
    final timeFee = analysis.estimatedMinutes * perMinuteYen;
    final subtotal = baseFeeYen + timeFee + difficultyFee;

    final demandRatio = (nearbyWaitingCount * _demandRatePerWaitingRequest)
        .clamp(0.0, _maxDemandRatio);
    final demandFee = (subtotal * demandRatio).round();

    return RequestEstimate(
      baseFeeYen: baseFeeYen,
      timeFeeYen: timeFee,
      difficultyFeeYen: difficultyFee,
      demandFeeYen: demandFee,
    );
  }
}
