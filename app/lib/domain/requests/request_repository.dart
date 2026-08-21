import 'package:flutter/foundation.dart';

import 'snow_request.dart';

abstract interface class RequestRepository implements Listenable {
  List<SnowRequest> get requests;

  SnowRequest? findById(String requestId);

  Future<void> publish(SnowRequest request);

  Future<bool> accept({
    required String requestId,
    required String workerId,
    required String workerName,
  });

  Future<bool> transitionWorkerStatus({
    required String requestId,
    required String workerId,
    required RequestStatus nextStatus,
    bool safetyChecksConfirmed = false,
    String? afterImageAsset,
    String? workMemo,
  });

  Future<bool> approveCompletion({
    required String requestId,
    required String ownerId,
  });

  Future<bool> submitRating({
    required String requestId,
    required String ownerId,
    required int rating,
    String? comment,
  });

  /// Raises a dispute (spec 09章: "matched以降 → cancelled / disputed 当事者
  /// 理由必須"). [reporterId] must be the request's owner or assigned
  /// worker, and the request must be in one of [disputableRequestStatuses].
  Future<bool> reportProblem({
    required String requestId,
    required String reporterId,
    required String reason,
  });

  /// Cancels a still-unmatched request (spec 09章: "waiting → cancelled
  /// 依頼者 未受注。キャンセル理由を記録。"). Only the owner may cancel, and
  /// only while the request is still [RequestStatus.waiting].
  Future<bool> cancel({
    required String requestId,
    required String ownerId,
    required String reason,
  });
}
