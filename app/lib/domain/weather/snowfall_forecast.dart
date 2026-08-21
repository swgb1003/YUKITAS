/// A single-region snowfall forecast (spec 06.2 降雪予測), cached
/// server-side in `weatherSnapshots/niigata-shi` and refreshed periodically
/// by `functions/src/weather.ts`. The contest demo covers Niigata city only,
/// so there is exactly one snapshot rather than a per-region collection.
class SnowfallForecast {
  const SnowfallForecast({
    required this.temperatureC,
    required this.expectedSnowfallCm,
  });

  final int temperatureC;
  final int expectedSnowfallCm;

  /// Matches the threshold `functions/src/weather.ts` uses to decide whether
  /// to push registered family homes (spec 06.2: 大雪しきい値→家族へ通知).
  static const heavySnowThresholdCm = 20;

  bool get isHeavySnowWarning => expectedSnowfallCm >= heavySnowThresholdCm;

  String get headline =>
      expectedSnowfallCm > 0
          ? '明朝、${expectedSnowfallCm}cmの降雪予報です'
          : '当面まとまった降雪の予報はありません';

  String get detail =>
      isHeavySnowWarning
          ? '登録したご実家周辺で\n大雪が予想されています'
          : '登録した場所の積雪状況を\n引き続きお知らせします';

  /// Shown before the first snapshot arrives / in demo builds without
  /// Firebase - the same numbers the home screen hero shipped with
  /// originally (spec 02章 例示値: 新潟市 30cm予報).
  static const demo = SnowfallForecast(temperatureC: -2, expectedSnowfallCm: 30);
}
