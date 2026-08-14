import 'package:flutter/foundation.dart';

import 'region_stats.dart';

abstract interface class RegionStatsRepository implements Listenable {
  RegionStats get stats;
}
