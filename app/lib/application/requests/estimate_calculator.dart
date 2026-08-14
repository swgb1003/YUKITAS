import 'snow_analysis_provider.dart';

class RequestEstimate {
  const RequestEstimate({
    required this.baseFeeYen,
    required this.timeFeeYen,
    required this.difficultyFeeYen,
  });

  final int baseFeeYen;
  final int timeFeeYen;
  final int difficultyFeeYen;

  int get totalYen => baseFeeYen + timeFeeYen + difficultyFeeYen;
}

class EstimateCalculator {
  const EstimateCalculator();

  RequestEstimate calculate(SnowAnalysisResult analysis) {
    final difficultyFee = switch (analysis.difficulty) {
      <= 1 => 0,
      2 => 300,
      3 => 400,
      4 => 800,
      _ => 1200,
    };

    return RequestEstimate(
      baseFeeYen: 1000,
      timeFeeYen: analysis.estimatedMinutes * 40,
      difficultyFeeYen: difficultyFee,
    );
  }
}
