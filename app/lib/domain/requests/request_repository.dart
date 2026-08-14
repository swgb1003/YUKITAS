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
}
