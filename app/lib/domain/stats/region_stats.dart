/// Region-wide activity counters shown on the home screen and completion
/// card (spec ホーム画面 LOCAL IMPACT). Aggregated server-side in
/// `regionStats/summary` by Cloud Functions, since computing them client-side
/// would require reading every other user's requests directly.
class RegionStats {
  const RegionStats({
    required this.completedToday,
    required this.sosSupportedToday,
    required this.activeNow,
  });

  /// Requests that reached `completed` today (resets at JST midnight).
  final int completedToday;

  /// SOS-flagged requests completed today (resets at JST midnight).
  final int sosSupportedToday;

  /// Requests currently matched/moving/arrived/working/reviewing, region
  /// wide - a live gauge, not a daily count.
  final int activeNow;

  /// Shown before the first real snapshot arrives / in demo builds without
  /// Firebase, matching the numbers this screen shipped with originally.
  static const demo = RegionStats(
    completedToday: 347,
    sosSupportedToday: 32,
    activeNow: 86,
  );
}
