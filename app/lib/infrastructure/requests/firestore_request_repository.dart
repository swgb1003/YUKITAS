import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/requests/request_repository.dart';
import '../../domain/requests/snow_request.dart';
import 'snow_request_firestore_codec.dart';

class FirestoreRequestRepository extends ChangeNotifier
    implements RequestRepository {
  FirestoreRequestRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance {
    // Only this user's own requests, in either role. Open requests belonging
    // to other people are deliberately absent: they are readable through
    // `requestBoard` (FirestoreRequestBoardRepository), which carries a
    // coarse location and no address or photos. A query for every waiting
    // request would now be rejected by the rules, which is the point - it is
    // what used to hand every signed-in user the full document (AC-08).
    _subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[
      _listenTo('owned', _collection.where('ownerId', isEqualTo: userId)),
      _listenTo('assigned', _collection.where('workerId', isEqualTo: userId)),
    ];
  }

  final String userId;
  final FirebaseFirestore _firestore;
  final List<SnowRequest> _requests = <SnowRequest>[];
  final Map<String, Map<String, SnowRequest>> _queryResults =
      <String, Map<String, SnowRequest>>{};
  late final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subscriptions;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('requests');

  @override
  List<SnowRequest> get requests => List<SnowRequest>.unmodifiable(_requests);

  @override
  SnowRequest? findById(String requestId) {
    for (final request in _requests) {
      if (request.id == requestId) return request;
    }
    return null;
  }

  @override
  Future<void> publish(SnowRequest request) async {
    if (request.id.isEmpty || request.id.contains('/')) {
      throw ArgumentError.value(
        request.id,
        'request.id',
        'Invalid document ID',
      );
    }
    final ownedRequest = request.copyWith(
      ownerId: userId,
      status: RequestStatus.waiting,
    );
    final data = SnowRequestFirestoreCodec.encode(
      ownedRequest,
      updatedAt: FieldValue.serverTimestamp(),
    );
    data['createdAt'] = FieldValue.serverTimestamp();
    await _collection.doc(ownedRequest.id).set(data);
  }

  @override
  Future<bool> accept({
    required String requestId,
    required String workerId,
    required String workerName,
  }) async {
    if (workerId != userId || workerName.trim().isEmpty) return false;
    // A blind update, not a transaction: a worker cannot read a request they
    // have not taken yet, so there is nothing to read first. The atomicity
    // that used to come from the transaction now comes from the rules, which
    // evaluate `status == 'waiting' && workerId == null` server-side against
    // the current document - so two workers racing still leaves exactly one
    // winner, and the loser gets permission-denied.
    try {
      await _collection.doc(requestId).update(<String, Object?>{
        'status': RequestStatus.matched.name,
        'workerId': userId,
        'workerName': workerName.trim(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (error) {
      // permission-denied here means "someone else got there first", which
      // is a normal outcome rather than a fault.
      debugPrint('Accept rejected for $requestId: ${error.code}');
      return false;
    }
  }

  @override
  Future<bool> transitionWorkerStatus({
    required String requestId,
    required String workerId,
    required RequestStatus nextStatus,
    bool safetyChecksConfirmed = false,
    String? afterImageAsset,
    String? workMemo,
  }) async {
    if (workerId != userId) return false;
    return _runRequestTransaction(requestId, (transaction, reference, request) {
      if (request.workerId != userId) return false;
      final updates = <String, Object?>{
        'status': nextStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final validTransition = switch ((request.status, nextStatus)) {
        (RequestStatus.matched, RequestStatus.moving) => () {
          updates['movingAt'] = FieldValue.serverTimestamp();
          return true;
        }(),
        (RequestStatus.moving, RequestStatus.arrived) => () {
          updates['arrivedAt'] = FieldValue.serverTimestamp();
          return true;
        }(),
        (RequestStatus.arrived, RequestStatus.working)
            when safetyChecksConfirmed =>
          () {
            updates['safetyConfirmedAt'] = FieldValue.serverTimestamp();
            updates['startedAt'] = FieldValue.serverTimestamp();
            return true;
          }(),
        (RequestStatus.working, RequestStatus.reviewing)
            when afterImageAsset != null &&
                afterImageAsset.isNotEmpty &&
                workMemo != null &&
                workMemo.trim().isNotEmpty =>
          () {
            updates['afterImageAsset'] = afterImageAsset;
            updates['workMemo'] = workMemo.trim();
            updates['submittedAt'] = FieldValue.serverTimestamp();
            return true;
          }(),
        _ => false,
      };
      if (!validTransition) return false;
      transaction.update(reference, updates);
      return true;
    });
  }

  @override
  Future<bool> approveCompletion({
    required String requestId,
    required String ownerId,
  }) async {
    if (ownerId != userId) return false;
    return _runRequestTransaction(requestId, (transaction, reference, request) {
      if (request.ownerId != userId ||
          request.status != RequestStatus.reviewing ||
          request.afterImageAsset == null ||
          request.workMemo == null) {
        return false;
      }
      transaction.update(reference, <String, Object?>{
        'status': RequestStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
        'paymentStatus': DemoPaymentStatus.paid.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  @override
  Future<bool> submitRating({
    required String requestId,
    required String ownerId,
    required int rating,
    String? comment,
  }) async {
    if (ownerId != userId || rating < 1 || rating > 5) return false;
    return _runRequestTransaction(requestId, (transaction, reference, request) {
      if (request.ownerId != userId ||
          request.status != RequestStatus.completed ||
          request.paymentStatus != DemoPaymentStatus.paid) {
        return false;
      }
      transaction.update(reference, <String, Object?>{
        'rating': rating,
        'ratingComment': comment?.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  @override
  Future<bool> reportProblem({
    required String requestId,
    required String reporterId,
    required String reason,
  }) async {
    if (reporterId != userId) return false;
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) return false;
    return _runRequestTransaction(requestId, (transaction, reference, request) {
      final isParty = userId == request.ownerId || userId == request.workerId;
      if (!isParty || !disputableRequestStatuses.contains(request.status)) {
        return false;
      }
      transaction.update(reference, <String, Object?>{
        'status': RequestStatus.disputed.name,
        'disputeReason': trimmedReason,
        'disputedAt': FieldValue.serverTimestamp(),
        'disputedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  @override
  Future<bool> cancel({
    required String requestId,
    required String ownerId,
    required String reason,
  }) async {
    if (ownerId != userId) return false;
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) return false;
    return _runRequestTransaction(requestId, (transaction, reference, request) {
      if (request.ownerId != userId ||
          !ownerCancellableStatuses.contains(request.status)) {
        return false;
      }
      transaction.update(reference, <String, Object?>{
        'status': RequestStatus.cancelled.name,
        'cancelReason': trimmedReason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  @override
  Future<bool> releaseAssignment({
    required String requestId,
    required String workerId,
    required String reason,
  }) async {
    if (workerId != userId) return false;
    if (reason.trim().isEmpty) return false;
    return _runRequestTransaction(requestId, (transaction, reference, request) {
      if (request.workerId != userId ||
          !workerReleasableStatuses.contains(request.status)) {
        return false;
      }
      transaction.update(reference, <String, Object?>{
        'status': RequestStatus.waiting.name,
        'workerId': null,
        'workerName': null,
        'acceptedAt': null,
        'movingAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<bool> _runRequestTransaction(
    String requestId,
    bool Function(
      Transaction transaction,
      DocumentReference<Map<String, dynamic>> reference,
      SnowRequest request,
    )
    update,
  ) async {
    final reference = _collection.doc(requestId);
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(reference);
        final data = snapshot.data();
        if (!snapshot.exists || data == null) return false;
        final request = SnowRequestFirestoreCodec.decode(snapshot.id, data);
        return update(transaction, reference, request);
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Firestore request transaction failed: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _listenTo(
    String queryName,
    Query<Map<String, dynamic>> query,
  ) {
    return query
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) => _replaceQueryResults(queryName, snapshot),
          onError: (Object error, StackTrace stackTrace) {
            _handleSnapshotError(queryName, error, stackTrace);
          },
        );
  }

  void _replaceQueryResults(
    String queryName,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final nextResults = <String, SnowRequest>{};
    for (final document in snapshot.docs) {
      try {
        nextResults[document.id] = SnowRequestFirestoreCodec.decode(
          document.id,
          document.data(),
        );
      } on FormatException catch (error) {
        debugPrint('Skipped invalid request ${document.id}: $error');
      }
    }
    _queryResults[queryName] = nextResults;
    final combined = <String, SnowRequest>{};
    for (final results in _queryResults.values) {
      combined.addAll(results);
    }
    final nextRequests = combined.values.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _requests
      ..clear()
      ..addAll(nextRequests);
    notifyListeners();
  }

  void _handleSnapshotError(
    String queryName,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('Firestore request sync failed for $queryName: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
