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

  /// Cancels a request with a recorded reason (spec 09章). Only the owner
  /// may cancel, and only from [ownerCancellableStatuses] - which now
  /// includes the post-match states, so a requester whose worker never
  /// arrives is no longer stuck with no way out.
  Future<bool> cancel({
    required String requestId,
    required String ownerId,
    required String reason,
  });

  /// Hands an accepted job back to the pool, returning it to
  /// [RequestStatus.waiting] and clearing the assignment.
  ///
  /// Allowed from [workerReleasableStatuses] only - before any snow has been
  /// moved. This is the non-accusatory exit a worker needs when they cannot
  /// make it; reporting a problem is for when something is actually wrong.
  Future<bool> releaseAssignment({
    required String requestId,
    required String workerId,
    required String reason,
  });
}
