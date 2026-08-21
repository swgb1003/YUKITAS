import 'package:flutter/foundation.dart';

import '../../domain/requests/request_board_repository.dart';
import '../../domain/requests/request_repository.dart';
import '../../domain/requests/request_summary.dart';

/// Demo/offline stand-in that projects the in-memory requests the same way
/// Cloud Functions project them into `requestBoard` for Firebase builds.
///
/// There is no privacy boundary to enforce here - the data is fabricated and
/// never leaves the process - but going through the same [RequestSummary]
/// projection keeps demo builds honest about what a worker can actually see
/// before accepting, so the two paths cannot drift apart.
class InMemoryRequestBoardRepository extends ChangeNotifier
    implements RequestBoardRepository {
  InMemoryRequestBoardRepository({required RequestRepository requests})
    : _requests = requests {
    _requests.addListener(notifyListeners);
  }

  final RequestRepository _requests;

  @override
  List<RequestSummary> get summaries =>
      _requests.requests
          .where((request) => boardVisibleStatuses.contains(request.status))
          .map(RequestSummary.fromRequest)
          .toList(growable: false);

  @override
  void setOrigin({required double latitude, required double longitude}) {
    // The demo dataset is a handful of requests around one town; there is
    // nothing to re-scope.
  }

  @override
  void dispose() {
    _requests.removeListener(notifyListeners);
    super.dispose();
  }
}
