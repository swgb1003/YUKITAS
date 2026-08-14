import 'package:flutter/foundation.dart';

import '../../domain/stats/region_stats.dart';
import '../../domain/stats/region_stats_repository.dart';

/// Static stand-in for demo/non-Firebase builds - there's no Cloud Functions
/// aggregate to read, so this just keeps showing the numbers the screens
/// originally shipped with.
class DemoRegionStatsRepository extends ChangeNotifier
    implements RegionStatsRepository {
  @override
  RegionStats get stats => RegionStats.demo;
}
