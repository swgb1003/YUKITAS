import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_config.dart';
import '../application/media/request_photo_service.dart';
import '../application/notifications/push_notification_service.dart';
import '../application/requests/snow_analysis_provider.dart';
import '../application/requests/worker_achievements.dart';
import '../core/widgets/push_notification_scope.dart';
import '../core/widgets/yukitas_bottom_navigation.dart';
import '../domain/places/saved_place_repository.dart';
import '../domain/requests/request_repository.dart';
import '../domain/requests/snow_request.dart';
import '../domain/stats/region_stats_repository.dart';
import '../domain/weather/weather_forecast_repository.dart';
import '../features/common/profile_screen.dart';
import '../features/requester/request_creation_flow.dart';
import '../features/requester/request_history_screen.dart';
import '../features/requester/request_status_screen.dart';
import '../features/requester/requester_home_screen.dart';
import '../features/requester/requester_snow_map_screen.dart';
import '../features/requester/saved_places_screen.dart';
import '../features/worker/worker_achievements_screen.dart';
import '../features/worker/worker_active_request_screen.dart';
import '../features/worker/worker_list_screen.dart';
import '../features/worker/worker_map_screen.dart';
import '../features/worker/worker_request_detail_screen.dart';
import '../infrastructure/notifications/demo_push_notification_service.dart';
import '../infrastructure/places/in_memory_saved_place_repository.dart';
import '../infrastructure/requests/in_memory_request_repository.dart';
import '../infrastructure/stats/demo_region_stats_repository.dart';
import '../infrastructure/weather/demo_weather_forecast_repository.dart';
import 'user_mode.dart';

class ModeShell extends StatefulWidget {
  const ModeShell({
    super.key,
    this.repository,
    this.disposeRepository = false,
    this.savedPlaceRepository,
    this.disposeSavedPlaceRepository = false,
    this.pushNotificationService,
    this.disposePushNotificationService = false,
    this.regionStatsRepository,
    this.disposeRegionStatsRepository = false,
    this.weatherForecastRepository,
    this.disposeWeatherForecastRepository = false,
    this.currentUserId = 'demo-worker-takumi',
    this.currentUserName = '佐藤 拓海さん',
    this.photoPicker,
    this.photoStorage = const DemoRequestPhotoStorage(),
    this.analysisProvider = const DemoSnowAnalysisProvider(),
    this.onSignOut,
  });

  final RequestRepository? repository;
  final bool disposeRepository;
  final SavedPlaceRepository? savedPlaceRepository;
  final bool disposeSavedPlaceRepository;
  final PushNotificationService? pushNotificationService;
  final bool disposePushNotificationService;
  final RegionStatsRepository? regionStatsRepository;
  final bool disposeRegionStatsRepository;
  final WeatherForecastRepository? weatherForecastRepository;
  final bool disposeWeatherForecastRepository;
  final String currentUserId;
  final String currentUserName;
  final RequestPhotoPicker? photoPicker;
  final RequestPhotoStorage photoStorage;
  final SnowAnalysisProvider analysisProvider;
  final VoidCallback? onSignOut;

  @override
  State<ModeShell> createState() => _ModeShellState();
}

class _ModeShellState extends State<ModeShell> {
  late final RequestRepository _repository;
  late final SavedPlaceRepository _savedPlaceRepository;
  late final PushNotificationService _pushNotificationService;
  late final RegionStatsRepository _regionStatsRepository;
  late final WeatherForecastRepository _weatherForecastRepository;
  UserMode _mode = UserMode.requester;
  int _requesterIndex = 0;
  int _workerIndex = 0;

  /// The requester's own in-flight request (R-01) and the worker's own
  /// assigned job (W-04) are tracked separately - one account can be both
  /// at once (e.g. mid-job as a worker while also waiting on their own
  /// request), and merging them into one id let one role's job hijack the
  /// other role's tab (the worker's active job would take over the
  /// requester's 依頼履歴 tab as if it were the requester's own request).
  String? _activeOwnedRequestId;
  String? _activeAssignedRequestId;

  /// Requests the requester has already rated and closed out. They stay in
  /// the history list but must not be re-adopted as the tracked request,
  /// otherwise the progress screen would keep taking over the 依頼履歴 tab.
  final Set<String> _finishedRequestIds = <String>{};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InMemoryRequestRepository();
    _savedPlaceRepository =
        widget.savedPlaceRepository ?? InMemorySavedPlaceRepository();
    _pushNotificationService =
        widget.pushNotificationService ?? DemoPushNotificationService();
    _regionStatsRepository =
        widget.regionStatsRepository ?? DemoRegionStatsRepository();
    _weatherForecastRepository =
        widget.weatherForecastRepository ?? DemoWeatherForecastRepository();
    _restoreActiveRequest();
    _repository.addListener(_repositoryChanged);
    _savedPlaceRepository.addListener(_savedPlacesChanged);
    _regionStatsRepository.addListener(_regionStatsChanged);
    _weatherForecastRepository.addListener(_weatherForecastChanged);
    unawaited(
      _pushNotificationService.initialize().then(
        (_) => _pushNotificationService.setWorkerSubscribed(
          _mode == UserMode.worker,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _repository.removeListener(_repositoryChanged);
    if ((widget.repository == null || widget.disposeRepository) &&
        _repository is ChangeNotifier) {
      (_repository as ChangeNotifier).dispose();
    }
    _savedPlaceRepository.removeListener(_savedPlacesChanged);
    if ((widget.savedPlaceRepository == null ||
            widget.disposeSavedPlaceRepository) &&
        _savedPlaceRepository is ChangeNotifier) {
      (_savedPlaceRepository as ChangeNotifier).dispose();
    }
    if ((widget.pushNotificationService == null ||
            widget.disposePushNotificationService) &&
        _pushNotificationService is ChangeNotifier) {
      (_pushNotificationService as ChangeNotifier).dispose();
    }
    _regionStatsRepository.removeListener(_regionStatsChanged);
    if ((widget.regionStatsRepository == null ||
            widget.disposeRegionStatsRepository) &&
        _regionStatsRepository is ChangeNotifier) {
      (_regionStatsRepository as ChangeNotifier).dispose();
    }
    _weatherForecastRepository.removeListener(_weatherForecastChanged);
    if ((widget.weatherForecastRepository == null ||
            widget.disposeWeatherForecastRepository) &&
        _weatherForecastRepository is ChangeNotifier) {
      (_weatherForecastRepository as ChangeNotifier).dispose();
    }
    super.dispose();
  }

  void _repositoryChanged() {
    if (!mounted) return;
    setState(_restoreActiveRequest);
  }

  void _savedPlacesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _regionStatsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _weatherForecastChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// A request the requester has already closed out. Rated work stays
  /// finished across restarts, while [_finishedRequestIds] covers the
  /// in-session case where the rating write has not landed yet.
  bool _isFinished(SnowRequest request) =>
      _finishedRequestIds.contains(request.id) ||
      (request.status == RequestStatus.completed && request.rating != null);

  void _restoreActiveRequest() {
    _activeOwnedRequestId = _restoreTrackedRequestId(
      _activeOwnedRequestId,
      (request) => request.ownerId == widget.currentUserId,
    );
    _activeAssignedRequestId = _restoreTrackedRequestId(
      _activeAssignedRequestId,
      (request) => request.workerId == widget.currentUserId,
    );
    if (_activeOwnedRequestId != null) _requesterIndex = 2;
  }

  String? _restoreTrackedRequestId(
    String? currentId,
    bool Function(SnowRequest request) belongsToRole,
  ) {
    final selected = currentId == null ? null : _repository.findById(currentId);
    if (selected != null &&
        _isTrackedStatus(selected.status) &&
        !_isFinished(selected)) {
      return currentId;
    }
    for (final request in _repository.requests) {
      if (!_isTrackedStatus(request.status)) continue;
      if (_isFinished(request)) continue;
      if (belongsToRole(request)) return request.id;
    }
    return null;
  }

  /// Requests shown on the aggregate 地域雪マップ (home preview + full map):
  /// completed jobs are done and clutter a map meant to show current
  /// activity, so they drop off once finished. A single request's own
  /// status screen still shows its pin after completion - see
  /// RequestStatusScreen's direct SnowMap(requests: [request]) usage.
  List<SnowRequest> get _mapVisibleRequests =>
      _repository.requests
          .where(
            (request) =>
                request.status != RequestStatus.draft &&
                request.status != RequestStatus.cancelled &&
                request.status != RequestStatus.completed &&
                request.status != RequestStatus.disputed,
          )
          .toList();

  List<SnowRequest> get _availableRequests =>
      _repository.requests
          .where(
            (request) =>
                request.status == RequestStatus.waiting &&
                request.ownerId != widget.currentUserId,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<SnowRequest> get _ownedRequests =>
      _repository.requests
          .where(
            (request) =>
                request.ownerId == widget.currentUserId &&
                request.status != RequestStatus.draft,
          )
          .toList()
        ..sort(
          (a, b) => (b.completedAt ?? b.createdAt).compareTo(
            a.completedAt ?? a.createdAt,
          ),
        );

  List<SnowRequest> get _assignedRequests =>
      _repository.requests
          .where((request) => request.workerId == widget.currentUserId)
          .toList()
        ..sort(
          (a, b) => (b.completedAt ?? b.createdAt).compareTo(
            a.completedAt ?? a.createdAt,
          ),
        );

  WorkerAchievements get _achievements => WorkerAchievements.fromRequests(
    _assignedRequests,
    includeDemoBaseline: AppConfig.showsDemoTools,
  );

  SnowRequest? get _activeOwnedRequest =>
      _activeOwnedRequestId == null
          ? null
          : _repository.findById(_activeOwnedRequestId!);

  SnowRequest? get _activeAssignedRequest =>
      _activeAssignedRequestId == null
          ? null
          : _repository.findById(_activeAssignedRequestId!);

  bool _isActiveWorkerStatus(RequestStatus status) =>
      status == RequestStatus.matched ||
      status == RequestStatus.moving ||
      status == RequestStatus.arrived ||
      status == RequestStatus.working ||
      status == RequestStatus.reviewing ||
      status == RequestStatus.completed ||
      status == RequestStatus.disputed;

  bool _isTrackedStatus(RequestStatus status) =>
      status == RequestStatus.waiting || _isActiveWorkerStatus(status);

  void _toggleMode() {
    setState(() {
      _mode =
          _mode == UserMode.requester ? UserMode.worker : UserMode.requester;
      unawaited(
        _pushNotificationService.setWorkerSubscribed(
          _mode == UserMode.worker,
        ),
      );
      if (_mode == UserMode.worker) {
        final assignedRequest = _latestRequestWhere(
          (request) =>
              request.workerId == widget.currentUserId &&
              _isActiveWorkerStatus(request.status) &&
              !_isFinished(request),
        );
        if (assignedRequest != null) {
          _activeAssignedRequestId = assignedRequest.id;
        }
        _workerIndex =
            _activeAssignedRequest != null &&
                    _isActiveWorkerStatus(_activeAssignedRequest!.status)
                ? 0
                : _activeAssignedRequest?.status == RequestStatus.waiting
                ? 1
                : _workerIndex;
      } else {
        final ownedRequest = _latestRequestWhere(
          (request) =>
              request.ownerId == widget.currentUserId &&
              _isTrackedStatus(request.status) &&
              !_isFinished(request),
        );
        if (ownedRequest != null) {
          _activeOwnedRequestId = ownedRequest.id;
        }
        if (_activeOwnedRequest != null) _requesterIndex = 2;
      }
    });
  }

  SnowRequest? _latestRequestWhere(bool Function(SnowRequest) test) {
    for (final request in _repository.requests) {
      if (test(request)) return request;
    }
    return null;
  }

  void _openSavedPlaces() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => SavedPlacesScreen(
              repository: _savedPlaceRepository,
              onToggleMode: _toggleMode,
            ),
      ),
    );
  }

  void _selectDestination(int index) {
    setState(() {
      if (_mode == UserMode.requester) {
        _requesterIndex = index;
      } else {
        _workerIndex = index;
      }
    });
  }

  Future<void> _startRequestCreation() async {
    final requestId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (context) => RequestCreationFlow(
              analysisProvider: widget.analysisProvider,
              onPublish: _repository.publish,
              savedPlaces: _savedPlaceRepository.places,
              photoPicker: widget.photoPicker,
              photoStorage: widget.photoStorage,
              nearbyWaitingCount: _availableRequests.length,
            ),
      ),
    );
    if (!mounted || requestId == null) return;
    setState(() {
      _activeOwnedRequestId = requestId;
      _requesterIndex = 2;
    });
  }

  Future<void> _openWorkerRequest(SnowRequest request) async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (context) => WorkerRequestDetailScreen(
              request: request,
              onAccept:
                  () => _repository.accept(
                    requestId: request.id,
                    workerId: widget.currentUserId,
                    workerName: widget.currentUserName,
                  ),
            ),
      ),
    );
    if (!mounted) return;
    if (accepted == true) {
      setState(() {
        _activeAssignedRequestId = request.id;
        _workerIndex = 0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('受注が確定し、依頼者へ通知しました')));
    }
  }

  Future<bool> _transitionActiveRequest(
    RequestStatus nextStatus,
    bool safetyChecksConfirmed,
    String? afterImageAsset,
    String? workMemo,
  ) async {
    final request = _activeAssignedRequest;
    if (request == null) return false;
    return _repository.transitionWorkerStatus(
      requestId: request.id,
      workerId: widget.currentUserId,
      nextStatus: nextStatus,
      safetyChecksConfirmed: safetyChecksConfirmed,
      afterImageAsset: afterImageAsset,
      workMemo: workMemo,
    );
  }

  Future<bool> _approveCompletion() async {
    final request = _activeOwnedRequest;
    if (request == null) return false;
    return _repository.approveCompletion(
      requestId: request.id,
      ownerId: request.ownerId,
    );
  }

  Future<bool> _reportAssignedRequestProblem(String reason) async {
    final request = _activeAssignedRequest;
    if (request == null) return false;
    return _repository.reportProblem(
      requestId: request.id,
      reporterId: widget.currentUserId,
      reason: reason,
    );
  }

  Future<bool> _reportOwnedRequestProblem(String reason) async {
    final request = _activeOwnedRequest;
    if (request == null) return false;
    return _repository.reportProblem(
      requestId: request.id,
      reporterId: widget.currentUserId,
      reason: reason,
    );
  }

  Future<bool> _cancelOwnedRequest(String reason) async {
    final request = _activeOwnedRequest;
    if (request == null) return false;
    return _repository.cancel(
      requestId: request.id,
      ownerId: widget.currentUserId,
      reason: reason,
    );
  }

  Future<bool> _submitRating(int rating, String? comment) async {
    final request = _activeOwnedRequest;
    if (request == null) return false;
    final succeeded = await _repository.submitRating(
      requestId: request.id,
      ownerId: request.ownerId,
      rating: rating,
      comment: comment,
    );
    // Close the request out here rather than relying on the progress screen
    // surviving the await - the rating write can drop it from the tree.
    if (succeeded && mounted) _finishActiveRequest(request.id);
    return succeeded;
  }

  Widget _requesterBody() {
    return switch (_requesterIndex) {
      0 => RequesterHomeScreen(
        onToggleMode: _toggleMode,
        onCreateRequest: _startRequestCreation,
        requests: _mapVisibleRequests,
        onOpenSnowMap: () => _selectDestination(1),
        stats: _regionStatsRepository.stats,
        forecast: _weatherForecastRepository.forecast,
      ),
      1 => RequesterSnowMapScreen(
        key: const ValueKey('requester-snow-map'),
        requests: _mapVisibleRequests,
        onToggleMode: _toggleMode,
      ),
      2 when _activeOwnedRequest != null => RequestStatusScreen(
        request: _activeOwnedRequest!,
        onToggleMode: _toggleMode,
        onApproveCompletion: _approveCompletion,
        onSubmitRating: _submitRating,
        onReportProblem: _reportOwnedRequestProblem,
        onCancel: _cancelOwnedRequest,
        onFinish: () => _finishActiveRequest(),
        completedToday: _regionStatsRepository.stats.completedToday,
      ),
      2 => RequestHistoryScreen(
        key: const ValueKey('requester-history'),
        requests: _ownedRequests,
        onToggleMode: _toggleMode,
        onCreateRequest: _startRequestCreation,
      ),
      _ => ProfileScreen(
        key: const ValueKey('requester-profile'),
        mode: _mode,
        userName: widget.currentUserName,
        ownedRequests: _ownedRequests,
        achievements: _achievements,
        savedPlaces: _savedPlaceRepository.places,
        onOpenSavedPlaces: _openSavedPlaces,
        onToggleMode: _toggleMode,
        onSignOut: widget.onSignOut,
      ),
    };
  }

  void _finishActiveRequest([String? requestId]) {
    setState(() {
      final finishedId = requestId ?? _activeOwnedRequestId;
      if (finishedId != null) _finishedRequestIds.add(finishedId);
      _activeOwnedRequestId = null;
      _requesterIndex = 0;
    });
  }

  Widget _workerBody() {
    if (_workerIndex == 0 &&
        _activeAssignedRequest != null &&
        _isActiveWorkerStatus(_activeAssignedRequest!.status)) {
      return WorkerActiveRequestScreen(
        request: _activeAssignedRequest!,
        onToggleMode: _toggleMode,
        onTransition: _transitionActiveRequest,
        onReportProblem: _reportAssignedRequestProblem,
        photoPicker: widget.photoPicker,
        photoStorage: widget.photoStorage,
        onFindNextRequest:
            () => setState(() {
              _activeAssignedRequestId = null;
              _workerIndex = 1;
            }),
      );
    }
    return switch (_workerIndex) {
      0 => WorkerMapScreen(
        onToggleMode: _toggleMode,
        onOpenList: () => _selectDestination(1),
        requests: _availableRequests,
        onOpenRequest: _openWorkerRequest,
      ),
      1 => WorkerListScreen(
        onToggleMode: _toggleMode,
        requests: _availableRequests,
        onOpenRequest: _openWorkerRequest,
      ),
      2 => WorkerAchievementsScreen(
        key: const ValueKey('worker-achievements'),
        achievements: _achievements,
        recentRequests: _assignedRequests,
        onToggleMode: _toggleMode,
        onFindWork: () => _selectDestination(1),
      ),
      _ => ProfileScreen(
        key: const ValueKey('worker-profile'),
        mode: _mode,
        userName: widget.currentUserName,
        ownedRequests: _ownedRequests,
        achievements: _achievements,
        savedPlaces: _savedPlaceRepository.places,
        onOpenSavedPlaces: _openSavedPlaces,
        onToggleMode: _toggleMode,
        onSignOut: widget.onSignOut,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final index = _mode == UserMode.requester ? _requesterIndex : _workerIndex;
    final trackedStatus =
        (_mode == UserMode.requester
                ? _activeOwnedRequest
                : _activeAssignedRequest)
            ?.status
            .name;

    return PushNotificationScope(
      service: _pushNotificationService,
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey('${_mode.name}-$index-$trackedStatus'),
            child:
                _mode == UserMode.requester ? _requesterBody() : _workerBody(),
          ),
        ),
        bottomNavigationBar: YukitasBottomNavigation(
          mode: _mode,
          currentIndex: index,
          onSelected: _selectDestination,
        ),
      ),
    );
  }
}
