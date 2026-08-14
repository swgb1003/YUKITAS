import '../../domain/requests/snow_request.dart';

/// Aggregated worker contribution figures shown on the 実績 tab and the
/// profile screen (spec 03章 地域貢献 / W-09).
class WorkerAchievements {
  const WorkerAchievements({
    required this.completedCount,
    required this.sosCount,
    required this.areaSqm,
    required this.earningsYen,
    required this.averageRating,
    required this.ratingCount,
    required this.includesDemoBaseline,
  });

  /// Points awarded per completed job, plus a bonus for SOS jobs. One SOS
  /// job is therefore +120pt, matching the figure used in the contest video.
  static const pointsPerJob = 100;
  static const sosBonusPoints = 20;
  static const pointsPerLevel = 1000;

  /// Pre-existing activity so the contest demo starts from a believable
  /// history instead of zero. Completing the single demo SOS job lands on
  /// 33件 / SOS 5件 / 428m², the numbers used in the design mockups. Only
  /// applied in demo builds, and always labelled as such on screen.
  static const _demoBaselineCompleted = 32;
  static const _demoBaselineSos = 4;
  static const _demoBaselineAreaSqm = 410.0;
  static const _demoBaselineEarningsYen = 86800;

  final int completedCount;
  final int sosCount;
  final double areaSqm;
  final int earningsYen;
  final double? averageRating;
  final int ratingCount;
  final bool includesDemoBaseline;

  int get points => completedCount * pointsPerJob + sosCount * sosBonusPoints;

  int get level => points ~/ pointsPerLevel + 1;

  int get pointsIntoLevel => points % pointsPerLevel;

  int get pointsToNextLevel => pointsPerLevel - pointsIntoLevel;

  double get levelProgress => pointsIntoLevel / pointsPerLevel;

  factory WorkerAchievements.fromRequests(
    List<SnowRequest> assignedRequests, {
    bool includeDemoBaseline = false,
  }) {
    final completed =
        assignedRequests
            .where((request) => request.status == RequestStatus.completed)
            .toList();
    final ratings =
        completed
            .map((request) => request.rating)
            .whereType<int>()
            .toList(growable: false);

    return WorkerAchievements(
      completedCount:
          completed.length + (includeDemoBaseline ? _demoBaselineCompleted : 0),
      sosCount:
          completed.where((request) => request.isSos).length +
          (includeDemoBaseline ? _demoBaselineSos : 0),
      areaSqm:
          completed.fold<double>(0, (sum, r) => sum + r.areaSqm) +
          (includeDemoBaseline ? _demoBaselineAreaSqm : 0),
      earningsYen:
          completed.fold<int>(0, (sum, r) => sum + r.priceYen) +
          (includeDemoBaseline ? _demoBaselineEarningsYen : 0),
      averageRating:
          ratings.isEmpty
              ? null
              : ratings.reduce((a, b) => a + b) / ratings.length,
      ratingCount: ratings.length,
      includesDemoBaseline: includeDemoBaseline,
    );
  }
}
