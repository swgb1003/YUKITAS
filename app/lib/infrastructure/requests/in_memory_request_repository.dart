import 'package:flutter/foundation.dart';

import '../../domain/requests/request_repository.dart';
import '../../domain/requests/snow_request.dart';

class InMemoryRequestRepository extends ChangeNotifier
    implements RequestRepository {
  InMemoryRequestRepository({List<SnowRequest>? seedRequests})
    : _requests = [...(seedRequests ?? _defaultRequests)];

  static List<SnowRequest> get _defaultRequests => [
    if (Uri.base.queryParameters['demo'] == 'progress')
      SnowRequest(
        id: 'demo-progress-001',
        ownerId: 'demo-owner-progress',
        placeName: '新潟の実家',
        approximateAddress: '新潟市中央区',
        latitude: 37.9161,
        longitude: 139.0364,
        workAreas: const ['玄関', '駐車場'],
        areaSqm: 18,
        snowDepthCm: 28,
        difficulty: 3,
        estimatedMinutes: 45,
        priceYen: 3200,
        isSos: true,
        sosReason: '高齢の家族宅',
        beforeImageAsset: 'assets/images/before_driveway.png',
        status: RequestStatus.matched,
        workerId: 'demo-worker-takumi',
        workerName: '佐藤 拓海さん',
        acceptedAt: DateTime(2026, 8, 13, 9),
        createdAt: DateTime(2026, 8, 13, 8, 50),
      ),
    SnowRequest(
      id: 'seed-sos-001',
      ownerId: 'seed-owner-001',
      placeName: '駐車場・玄関',
      approximateAddress: '新潟市中央区',
      latitude: 37.9105,
      longitude: 139.0410,
      workAreas: const ['駐車場', '玄関'],
      areaSqm: 18,
      snowDepthCm: 28,
      difficulty: 3,
      estimatedMinutes: 40,
      priceYen: 2800,
      isSos: true,
      sosReason: '高齢の家族宅を優先してほしい',
      beforeImageAsset: 'assets/images/before_driveway.png',
      status: RequestStatus.waiting,
      createdAt: DateTime(2026, 8, 13, 8, 42),
    ),
    SnowRequest(
      id: 'seed-normal-002',
      ownerId: 'seed-owner-002',
      placeName: '店舗前',
      approximateAddress: '新潟市中央区',
      latitude: 37.9200,
      longitude: 139.0300,
      workAreas: const ['通路'],
      areaSqm: 12,
      snowDepthCm: 20,
      difficulty: 2,
      estimatedMinutes: 30,
      priceYen: 2200,
      isSos: false,
      sosReason: null,
      beforeImageAsset: 'assets/images/before_driveway.png',
      status: RequestStatus.waiting,
      createdAt: DateTime(2026, 8, 13, 8, 31),
    ),
    SnowRequest(
      id: 'seed-reserved-003',
      ownerId: 'seed-owner-003',
      placeName: '車庫前',
      approximateAddress: '新潟市西区',
      latitude: 37.9223,
      longitude: 139.0000,
      workAreas: const ['車庫前'],
      areaSqm: 24,
      snowDepthCm: 34,
      difficulty: 4,
      estimatedMinutes: 55,
      priceYen: 3600,
      isSos: false,
      sosReason: null,
      beforeImageAsset: 'assets/images/before_driveway.png',
      status: RequestStatus.waiting,
      createdAt: DateTime(2026, 8, 13, 8, 15),
    ),
  ];

  final List<SnowRequest> _requests;

  @override
  List<SnowRequest> get requests => List.unmodifiable(_requests);

  @override
  SnowRequest? findById(String requestId) {
    for (final request in _requests) {
      if (request.id == requestId) return request;
    }
    return null;
  }

  @override
  Future<void> publish(SnowRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final existingIndex = _requests.indexWhere((item) => item.id == request.id);
    if (existingIndex == -1) {
      _requests.insert(0, request);
    } else {
      _requests[existingIndex] = request;
    }
    notifyListeners();
  }

  @override
  Future<bool> accept({
    required String requestId,
    required String workerId,
    required String workerName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final index = _requests.indexWhere((item) => item.id == requestId);
    if (index == -1 || !_requests[index].isAvailable) return false;

    _requests[index] = _requests[index].copyWith(
      status: RequestStatus.matched,
      workerId: workerId,
      workerName: workerName,
      acceptedAt: DateTime.now(),
    );
    notifyListeners();
    return true;
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
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final index = _requests.indexWhere((item) => item.id == requestId);
    if (index == -1) return false;

    final request = _requests[index];
    if (request.workerId != workerId) return false;

    final validTransition = switch ((request.status, nextStatus)) {
      (RequestStatus.matched, RequestStatus.moving) => true,
      (RequestStatus.moving, RequestStatus.arrived) => true,
      (RequestStatus.arrived, RequestStatus.working) => safetyChecksConfirmed,
      (RequestStatus.working, RequestStatus.reviewing) =>
        afterImageAsset != null &&
            afterImageAsset.isNotEmpty &&
            workMemo != null &&
            workMemo.trim().isNotEmpty,
      _ => false,
    };
    if (!validTransition) return false;

    final now = DateTime.now();
    _requests[index] = request.copyWith(
      status: nextStatus,
      movingAt: nextStatus == RequestStatus.moving ? now : null,
      arrivedAt: nextStatus == RequestStatus.arrived ? now : null,
      startedAt: nextStatus == RequestStatus.working ? now : null,
      safetyConfirmedAt:
          nextStatus == RequestStatus.working && safetyChecksConfirmed
              ? now
              : null,
      afterImageAsset:
          nextStatus == RequestStatus.reviewing ? afterImageAsset : null,
      workMemo: nextStatus == RequestStatus.reviewing ? workMemo?.trim() : null,
      submittedAt: nextStatus == RequestStatus.reviewing ? now : null,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> approveCompletion({
    required String requestId,
    required String ownerId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final index = _requests.indexWhere((item) => item.id == requestId);
    if (index == -1) return false;

    final request = _requests[index];
    if (request.ownerId != ownerId ||
        request.status != RequestStatus.reviewing ||
        request.afterImageAsset == null ||
        request.workMemo == null) {
      return false;
    }

    _requests[index] = request.copyWith(
      status: RequestStatus.completed,
      completedAt: DateTime.now(),
      paymentStatus: DemoPaymentStatus.paid,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> submitRating({
    required String requestId,
    required String ownerId,
    required int rating,
    String? comment,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final index = _requests.indexWhere((item) => item.id == requestId);
    if (index == -1 || rating < 1 || rating > 5) return false;

    final request = _requests[index];
    if (request.ownerId != ownerId ||
        request.status != RequestStatus.completed ||
        request.paymentStatus != DemoPaymentStatus.paid) {
      return false;
    }

    _requests[index] = request.copyWith(
      rating: rating,
      ratingComment: comment?.trim(),
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> reportProblem({
    required String requestId,
    required String reporterId,
    required String reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) return false;
    final index = _requests.indexWhere((item) => item.id == requestId);
    if (index == -1) return false;

    final request = _requests[index];
    final isParty =
        reporterId == request.ownerId || reporterId == request.workerId;
    if (!isParty || !disputableRequestStatuses.contains(request.status)) {
      return false;
    }

    _requests[index] = request.copyWith(
      status: RequestStatus.disputed,
      disputeReason: trimmedReason,
      disputedAt: DateTime.now(),
      disputedBy: reporterId,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> cancel({
    required String requestId,
    required String ownerId,
    required String reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) return false;
    final index = _requests.indexWhere((item) => item.id == requestId);
    if (index == -1) return false;

    final request = _requests[index];
    if (request.ownerId != ownerId ||
        !ownerCancellableStatuses.contains(request.status)) {
      return false;
    }

    _requests[index] = request.copyWith(
      status: RequestStatus.cancelled,
      cancelReason: trimmedReason,
      cancelledAt: DateTime.now(),
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> releaseAssignment({
    required String requestId,
    required String workerId,
    required String reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) return false;
    final index = _requests.indexWhere((item) => item.id == requestId);
    if (index == -1) return false;

    final request = _requests[index];
    if (request.workerId != workerId ||
        !workerReleasableStatuses.contains(request.status)) {
      return false;
    }

    _requests[index] = request.copyWith(
      status: RequestStatus.waiting,
      clearWorker: true,
    );
    notifyListeners();
    return true;
  }
}
