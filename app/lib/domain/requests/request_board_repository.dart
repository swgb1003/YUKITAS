import 'package:flutter/foundation.dart';

import 'request_summary.dart';

/// Reads the public board of nearby requests (see [RequestSummary]).
///
/// Scoped to a geographic origin rather than fetching every open request in
/// the country, which is what the previous global `status == waiting` query
/// did (spec 08.3 asks for region-scoped queries and indexes).
abstract interface class RequestBoardRepository implements Listenable {
  List<RequestSummary> get summaries;

  /// Re-scopes the board to the cells around this position. Cheap to call
  /// repeatedly - implementations only resubscribe when the covered cells
  /// actually change.
  void setOrigin({required double latitude, required double longitude});
}
