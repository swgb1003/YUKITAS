enum RequestStatus {
  draft,
  waiting,
  matched,
  moving,
  arrived,
  working,
  reviewing,
  completed,
  cancelled,
  disputed,
}

extension RequestStatusPresentation on RequestStatus {
  String get requesterLabel => switch (this) {
    RequestStatus.draft => '入力中',
    RequestStatus.waiting => '近くのワーカーを探しています',
    RequestStatus.matched => 'ワーカーが見つかりました',
    RequestStatus.moving => 'ワーカーが向かっています',
    RequestStatus.arrived => 'ワーカーが到着しました',
    RequestStatus.working => '除雪作業中です',
    RequestStatus.reviewing => '完了写真を確認してください',
    RequestStatus.completed => '除雪完了',
    RequestStatus.cancelled => 'キャンセル済み',
    RequestStatus.disputed => '問題が報告されています',
  };

  String get workerLabel => switch (this) {
    RequestStatus.draft => '下書き',
    RequestStatus.waiting => '新しい除雪依頼',
    RequestStatus.matched => '依頼を受注しました',
    RequestStatus.moving => '現地へ向かってください',
    RequestStatus.arrived => '安全を確認して作業開始',
    RequestStatus.working => '作業中',
    RequestStatus.reviewing => '依頼者の確認待ち',
    RequestStatus.completed => 'お疲れさまでした',
    RequestStatus.cancelled => 'キャンセル済み',
    RequestStatus.disputed => '問題の報告を受け、一時停止しています',
  };
}

/// Statuses at which either party (owner or assigned worker) may raise a
/// dispute (spec 09章: "matched以降 → cancelled / disputed 当事者 理由必須").
const disputableRequestStatuses = {
  RequestStatus.matched,
  RequestStatus.moving,
  RequestStatus.arrived,
  RequestStatus.working,
  RequestStatus.reviewing,
};

class SnowRequest {
  const SnowRequest({
    required this.id,
    required this.ownerId,
    required this.placeName,
    required this.approximateAddress,
    required this.latitude,
    required this.longitude,
    required this.workAreas,
    required this.areaSqm,
    required this.snowDepthCm,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.priceYen,
    required this.distanceKm,
    required this.isSos,
    required this.sosReason,
    required this.beforeImageAsset,
    required this.status,
    required this.createdAt,
    this.workerId,
    this.workerName,
    this.acceptedAt,
    this.movingAt,
    this.arrivedAt,
    this.safetyConfirmedAt,
    this.startedAt,
    this.afterImageAsset,
    this.workMemo,
    this.submittedAt,
    this.completedAt,
    this.paymentStatus = DemoPaymentStatus.authorized,
    this.rating,
    this.ratingComment,
    this.disputeReason,
    this.disputedAt,
    this.disputedBy,
    this.cancelReason,
    this.cancelledAt,
  });

  final String id;
  final String ownerId;
  final String placeName;
  final String approximateAddress;
  final double latitude;
  final double longitude;
  final List<String> workAreas;
  final double areaSqm;
  final int snowDepthCm;
  final int difficulty;
  final int estimatedMinutes;
  final int priceYen;
  final double distanceKm;
  final bool isSos;
  final String? sosReason;
  final String beforeImageAsset;
  final RequestStatus status;
  final DateTime createdAt;
  final String? workerId;
  final String? workerName;
  final DateTime? acceptedAt;
  final DateTime? movingAt;
  final DateTime? arrivedAt;
  final DateTime? safetyConfirmedAt;
  final DateTime? startedAt;
  final String? afterImageAsset;
  final String? workMemo;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final DemoPaymentStatus paymentStatus;
  final int? rating;
  final String? ratingComment;

  /// Set together when a party raises a dispute (spec 09章). [disputedBy]
  /// holds the reporting user's id, so the other party can be notified and
  /// no one else can claim to have filed a report they didn't.
  final String? disputeReason;
  final DateTime? disputedAt;
  final String? disputedBy;

  /// Set together when the owner cancels a still-unmatched request (spec
  /// 09章: "waiting → cancelled 依頼者 未受注。キャンセル理由を記録。").
  final String? cancelReason;
  final DateTime? cancelledAt;

  bool get isAvailable => status == RequestStatus.waiting && workerId == null;

  String get workTitle => '${workAreas.join('・')}の除雪';

  SnowRequest copyWith({
    String? id,
    String? ownerId,
    RequestStatus? status,
    String? workerId,
    String? workerName,
    DateTime? acceptedAt,
    DateTime? movingAt,
    DateTime? arrivedAt,
    DateTime? safetyConfirmedAt,
    DateTime? startedAt,
    String? afterImageAsset,
    String? workMemo,
    DateTime? submittedAt,
    DateTime? completedAt,
    DemoPaymentStatus? paymentStatus,
    int? rating,
    String? ratingComment,
    String? disputeReason,
    DateTime? disputedAt,
    String? disputedBy,
    String? cancelReason,
    DateTime? cancelledAt,
  }) {
    return SnowRequest(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      placeName: placeName,
      approximateAddress: approximateAddress,
      latitude: latitude,
      longitude: longitude,
      workAreas: workAreas,
      areaSqm: areaSqm,
      snowDepthCm: snowDepthCm,
      difficulty: difficulty,
      estimatedMinutes: estimatedMinutes,
      priceYen: priceYen,
      distanceKm: distanceKm,
      isSos: isSos,
      sosReason: sosReason,
      beforeImageAsset: beforeImageAsset,
      status: status ?? this.status,
      createdAt: createdAt,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      movingAt: movingAt ?? this.movingAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      safetyConfirmedAt: safetyConfirmedAt ?? this.safetyConfirmedAt,
      startedAt: startedAt ?? this.startedAt,
      afterImageAsset: afterImageAsset ?? this.afterImageAsset,
      workMemo: workMemo ?? this.workMemo,
      submittedAt: submittedAt ?? this.submittedAt,
      completedAt: completedAt ?? this.completedAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      disputeReason: disputeReason ?? this.disputeReason,
      disputedAt: disputedAt ?? this.disputedAt,
      disputedBy: disputedBy ?? this.disputedBy,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}

enum DemoPaymentStatus { authorized, paid }
