import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../application/media/request_photo_service.dart';
import '../../app/user_mode.dart';
import '../../core/formatters/yukitas_formatters.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/report_problem_dialog.dart';
import '../../core/widgets/request_progress_indicator.dart';
import '../../core/widgets/request_photo_image.dart';
import '../../core/widgets/route_map.dart';
import '../../core/widgets/screen_header.dart';
import '../../domain/requests/snow_request.dart';

class WorkerActiveRequestScreen extends StatefulWidget {
  const WorkerActiveRequestScreen({
    required this.request,
    required this.onToggleMode,
    required this.onTransition,
    required this.onReportProblem,
    required this.onFindNextRequest,
    this.photoPicker,
    this.photoStorage = const DemoRequestPhotoStorage(),
    super.key,
  });

  final SnowRequest request;
  final VoidCallback onToggleMode;
  final Future<bool> Function(
    RequestStatus nextStatus,
    bool safetyChecksConfirmed,
    String? afterImageAsset,
    String? workMemo,
  )
  onTransition;
  final Future<bool> Function(String reason) onReportProblem;
  final VoidCallback onFindNextRequest;
  final RequestPhotoPicker? photoPicker;
  final RequestPhotoStorage photoStorage;

  @override
  State<WorkerActiveRequestScreen> createState() =>
      _WorkerActiveRequestScreenState();
}

class _WorkerActiveRequestScreenState extends State<WorkerActiveRequestScreen> {
  final List<bool> _safetyChecks = [false, false, false];
  bool _busy = false;
  bool _paused = false;
  bool _afterPhotoCaptured = false;
  bool _pickingPhoto = false;
  PickedRequestPhoto? _afterPhoto;
  Uint8List? _afterPreviewBytes;
  final TextEditingController _workMemoController = TextEditingController(
    text: '玄関から門まで除雪しました。雪は敷地右側へまとめています。',
  );

  bool get _allSafetyChecksConfirmed =>
      _safetyChecks.every((checked) => checked);

  @override
  void initState() {
    super.initState();
    unawaited(_recoverAfterPhoto());
  }

  Future<void> _recoverAfterPhoto() async {
    final picker = widget.photoPicker;
    if (picker == null) return;
    try {
      final photo = await picker.recoverPending();
      if (!mounted || photo == null) return;
      setState(() {
        _afterPhoto = photo;
        _afterPreviewBytes = photo.bytes;
        _afterPhotoCaptured = true;
      });
    } on RequestPhotoFailure catch (error) {
      if (mounted) _showPhotoError(error.message);
    }
  }

  @override
  void dispose() {
    _workMemoController.dispose();
    super.dispose();
  }

  Future<bool> _transition(
    RequestStatus nextStatus, {
    bool safetyChecksConfirmed = false,
    String? afterImageAsset,
    String? workMemo,
  }) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final succeeded = await widget.onTransition(
      nextStatus,
      safetyChecksConfirmed,
      afterImageAsset,
      workMemo,
    );
    if (!mounted) return succeeded;
    setState(() => _busy = false);
    if (!succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('状態を更新できませんでした。内容を確認してください')),
      );
    }
    return succeeded;
  }

  Future<void> _pickAfterPhoto(RequestPhotoSource source) async {
    final picker = widget.photoPicker;
    if (picker == null || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final photo = await picker.pick(source);
      if (!mounted || photo == null) return;
      setState(() {
        _afterPhoto = photo;
        _afterPreviewBytes = photo.bytes;
        _afterPhotoCaptured = true;
      });
    } on RequestPhotoFailure catch (error) {
      if (mounted) _showPhotoError(error.message);
    } catch (_) {
      if (mounted) _showPhotoError('写真を選択できませんでした。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _showPhotoError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitCompletion() async {
    if (_busy) return;
    var afterImageSource = 'assets/images/after_driveway.png';
    if (_afterPhoto != null && widget.photoStorage.usesFirebase) {
      setState(() => _busy = true);
      try {
        afterImageSource = await widget.photoStorage.upload(
          requestId: widget.request.id,
          kind: RequestPhotoKind.after,
          photo: _afterPhoto!,
        );
      } on RequestPhotoFailure catch (error) {
        if (!mounted) return;
        setState(() => _busy = false);
        _showPhotoError(error.message);
        return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
    }
    final succeeded = await _transition(
      RequestStatus.reviewing,
      afterImageAsset: afterImageSource,
      workMemo: _workMemoController.text,
    );
    if (!succeeded && afterImageSource.startsWith('requestMedia/')) {
      try {
        await widget.photoStorage.delete(afterImageSource);
      } catch (_) {
        // Cleanup is best effort; the state transition error is already shown.
      }
    }
  }

  Future<void> _reportProblem() async {
    final reason = await promptForReportReason(context);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    final succeeded = await widget.onReportProblem(reason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!succeeded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('問題を報告できませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.request.status) {
      RequestStatus.matched => _buildMatched(context),
      RequestStatus.moving => _buildMoving(context),
      RequestStatus.arrived => _buildSafetyCheck(context),
      RequestStatus.working => _buildWorking(context),
      RequestStatus.reviewing => _buildAwaitingReview(context),
      RequestStatus.completed => _buildReward(context),
      RequestStatus.disputed => _buildDisputed(context),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildDisputed(BuildContext context) {
    return _WorkerPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YukitasScreenHeader(
              mode: UserMode.worker,
              eyebrow: 'ON HOLD',
              title: '問題が報告されています',
              subtitle: '確認のため作業を一時停止しています',
              onToggleMode: widget.onToggleMode,
            ),
            const SizedBox(height: 20),
            FrostedCard(
              radius: 27,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.report_gmailerrorred_outlined,
                        color: YukitasColors.sos,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '報告内容',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.request.disputeReason ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'このデモでは運営確認は省略し、依頼はここで一時停止として扱います。',
                    style: TextStyle(
                      color: YukitasColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            GradientActionButton(
              key: const Key('find-next-request'),
              label: '次の依頼を探す',
              icon: Icons.search_rounded,
              workerStyle: true,
              onPressed: widget.onFindNextRequest,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatched(BuildContext context) {
    return _WorkerPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          children: [
            YukitasScreenHeader(
              mode: UserMode.worker,
              eyebrow: 'REQUEST ACCEPTED',
              title: '受注しました',
              subtitle: '準備ができたら依頼者へ出発を共有',
              onToggleMode: widget.onToggleMode,
            ),
            const SizedBox(height: 28),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFFE9FBF6),
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3331C6A6),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: YukitasColors.safe,
                size: 52,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.request.workTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              widget.request.approximateAddress,
              style: const TextStyle(
                color: YukitasColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            FrostedCard(
              radius: 27,
              child: Column(
                children: [
                  const RequestProgressIndicator(status: RequestStatus.matched),
                  const Divider(height: 34),
                  _SummaryRow(
                    icon: Icons.payments_outlined,
                    label: '報酬',
                    value: formatYen(widget.request.priceYen),
                  ),
                  const SizedBox(height: 13),
                  _SummaryRow(
                    icon: Icons.schedule_rounded,
                    label: '作業目安',
                    value: '約${widget.request.estimatedMinutes}分',
                  ),
                  const SizedBox(height: 13),
                  _SummaryRow(
                    icon: Icons.route_outlined,
                    label: '現地まで',
                    value: '約8分',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            GradientActionButton(
              key: const Key('start-moving'),
              label: _busy ? '出発を共有しています' : '現地へ向かう',
              icon: Icons.navigation_rounded,
              workerStyle: true,
              onPressed: _busy ? null : () => _transition(RequestStatus.moving),
            ),
            const SizedBox(height: 10),
            const Text(
              '位置情報は依頼者に安全な粒度で共有されます',
              style: TextStyle(
                color: YukitasColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoving(BuildContext context) {
    return _WorkerPage(
      child: Stack(
        children: [
          Positioned.fill(
            child: RouteMap(
              destination: LatLng(widget.request.latitude, widget.request.longitude),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 128,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      YukitasColors.ice,
                      YukitasColors.ice.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: 14,
            child: YukitasScreenHeader(
              mode: UserMode.worker,
              eyebrow: 'LIVE NAVIGATION',
              title: '現地へ移動',
              subtitle: '依頼者へ位置を共有中',
              onToggleMode: widget.onToggleMode,
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: FrostedCard(
              padding: const EdgeInsets.fromLTRB(20, 17, 20, 20),
              radius: 29,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9FBF6),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Icon(
                          Icons.home_work_outlined,
                          color: YukitasColors.worker,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.request.workTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              widget.request.approximateAddress,
                              style: const TextStyle(
                                color: YukitasColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '8分',
                            style: TextStyle(
                              color: YukitasColors.deep,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '0.8 km',
                            style: TextStyle(
                              color: YukitasColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const RequestProgressIndicator(status: RequestStatus.moving),
                  const SizedBox(height: 17),
                  GradientActionButton(
                    key: const Key('mark-arrived'),
                    label: _busy ? '到着を共有しています' : '現地に到着',
                    icon: Icons.place_rounded,
                    workerStyle: true,
                    height: 54,
                    onPressed:
                        _busy ? null : () => _transition(RequestStatus.arrived),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCheck(BuildContext context) {
    const checkItems = [
      ('落雪・雪崩の危険はありません', '周囲と頭上を確認しました'),
      ('公道や屋根の作業は含まれません', '敷地内の地上作業に限定します'),
      ('雪の移動先を確認しました', '避難経路と排水口をふさぎません'),
    ];

    return _WorkerPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YukitasScreenHeader(
              mode: UserMode.worker,
              eyebrow: 'SAFETY FIRST',
              title: '作業前の安全確認',
              subtitle: '3項目を現地で確認してください',
              onToggleMode: widget.onToggleMode,
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: AspectRatio(
                aspectRatio: 1.9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RequestPhotoImage(
                      source: widget.request.beforeImageAsset,
                      fit: BoxFit.cover,
                    ),
                    const Positioned(
                      left: 14,
                      top: 14,
                      child: _PictureLabel(label: 'BEFORE'),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xDD0B2E47),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${widget.request.workAreas.join('・')} • ${formatArea(widget.request.areaSqm)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('確認項目', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 9),
            for (var index = 0; index < checkItems.length; index++) ...[
              _SafetyCheckTile(
                key: Key('safety-check-$index'),
                title: checkItems[index].$1,
                subtitle: checkItems[index].$2,
                checked: _safetyChecks[index],
                onChanged: (value) {
                  setState(() => _safetyChecks[index] = value);
                },
              ),
              if (index < checkItems.length - 1) const SizedBox(height: 9),
            ],
            const SizedBox(height: 16),
            GradientActionButton(
              key: const Key('start-work'),
              label: _busy ? '作業開始を共有しています' : '作業を開始する',
              icon: Icons.play_arrow_rounded,
              workerStyle: true,
              onPressed:
                  !_allSafetyChecksConfirmed || _busy
                      ? null
                      : () => _transition(
                        RequestStatus.working,
                        safetyChecksConfirmed: true,
                      ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                key: const Key('report-problem'),
                onPressed: _busy ? null : _reportProblem,
                icon: const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('依頼内容に問題がある'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorking(BuildContext context) {
    return _WorkerPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          children: [
            YukitasScreenHeader(
              mode: UserMode.worker,
              eyebrow: 'WORK IN PROGRESS',
              title: _paused ? '作業を一時停止中' : '除雪作業中',
              subtitle: '作業状況を依頼者へ共有しています',
              onToggleMode: widget.onToggleMode,
            ),
            const SizedBox(height: 22),
            FrostedCard(
              radius: 31,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: _paused ? 0.68 : 0.72,
                          strokeWidth: 13,
                          backgroundColor: YukitasColors.ice,
                          color:
                              _paused
                                  ? YukitasColors.warm
                                  : YukitasColors.worker,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            _paused ? '一時停止' : '00:18:42',
                            style: const TextStyle(
                              color: YukitasColors.deep,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            _paused ? '安全を確認して再開' : '経過時間',
                            style: const TextStyle(
                              color: YukitasColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 21),
                  const RequestProgressIndicator(status: RequestStatus.working),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _WorkMetric(label: '進捗', value: '68%')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WorkMetric(label: '残り目安', value: '約14分'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                key: const Key('toggle-work-pause'),
                onPressed: () => setState(() => _paused = !_paused),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _paused ? YukitasColors.worker : YukitasColors.deep,
                  side: BorderSide(
                    color:
                        _paused ? YukitasColors.worker : YukitasColors.outline,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: Icon(
                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                label: Text(_paused ? '作業を再開する' : '作業を一時停止'),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: const Color(0xFFE9FBF6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBCEDE1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: YukitasColors.safe),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      '安全を優先し、無理な作業は中断してください',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            TextButton.icon(
              onPressed:
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('依頼者への連絡画面を準備中です')),
                  ),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('依頼者へ連絡する'),
            ),
            const SizedBox(height: 8),
            GradientActionButton(
              key: const Key('open-completion'),
              label:
                  _pickingPhoto
                      ? '写真を準備しています'
                      : widget.photoPicker == null
                      ? '作業完了へ進む'
                      : '完了写真を追加',
              icon: Icons.camera_alt_outlined,
              workerStyle: true,
              onPressed:
                  _pickingPhoto
                      ? null
                      : widget.photoPicker == null
                      ? () => setState(() => _afterPhotoCaptured = true)
                      : () => _pickAfterPhoto(RequestPhotoSource.camera),
            ),
            if (widget.photoPicker != null)
              TextButton.icon(
                key: const Key('pick-after-gallery'),
                onPressed:
                    _pickingPhoto
                        ? null
                        : () => _pickAfterPhoto(RequestPhotoSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('写真ライブラリから選ぶ'),
              ),
            if (_afterPhotoCaptured) ...[
              const SizedBox(height: 20),
              _buildCompletionSubmission(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionSubmission(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '作業完了を送信',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 5),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'After写真と作業メモを確認',
            style: TextStyle(
              color: YukitasColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: AspectRatio(
            aspectRatio: 1.35,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_afterPreviewBytes != null)
                  Image.memory(_afterPreviewBytes!, fit: BoxFit.cover)
                else
                  Image.asset(
                    'assets/images/after_driveway.png',
                    fit: BoxFit.cover,
                  ),
                const Positioned(
                  left: 14,
                  top: 14,
                  child: _PictureLabel(label: 'AFTER'),
                ),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -20),
          child: FrostedCard(
            padding: const EdgeInsets.all(16),
            radius: 23,
            child: const Row(
              children: [
                _AiScoreRing(score: 86),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI CHECK',
                        style: TextStyle(
                          color: YukitasColors.action,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '通路確保を確認',
                        style: TextStyle(
                          color: YukitasColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'AI参考値・最終判断は依頼者です',
                        style: TextStyle(
                          color: YukitasColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Text('作業メモ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextField(
          key: const Key('work-memo'),
          controller: _workMemoController,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: YukitasColors.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: YukitasColors.outline),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: _WorkMetric(label: '作業時間', value: '38分')),
            SizedBox(width: 10),
            Expanded(child: _WorkMetric(label: '除雪面積', value: '18㎡')),
          ],
        ),
        const SizedBox(height: 16),
        GradientActionButton(
          key: const Key('submit-completion'),
          label: _busy ? '完了を送信しています' : '作業完了を送信',
          icon: Icons.check_rounded,
          workerStyle: true,
          onPressed: _busy ? null : _submitCompletion,
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            '依頼者の確認後、デモ報酬が確定します',
            style: TextStyle(
              color: YukitasColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAwaitingReview(BuildContext context) {
    return _WorkerPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          children: [
            YukitasScreenHeader(
              mode: UserMode.worker,
              eyebrow: 'SUBMITTED',
              title: '依頼者の確認待ち',
              subtitle: '完了写真と作業メモを送信しました',
              onToggleMode: widget.onToggleMode,
            ),
            const SizedBox(height: 38),
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9BEDE0), YukitasColors.safe],
                ),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x5531C6A6),
                    blurRadius: 32,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: const Icon(
                Icons.cloud_done_outlined,
                color: Colors.white,
                size: 58,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              '作業完了を送信しました',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '依頼者がBefore / Afterと作業報告を確認しています。\n承認後にデモ報酬へ反映されます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: YukitasColors.muted,
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 26),
            FrostedCard(
              radius: 27,
              child: Column(
                children: [
                  const RequestProgressIndicator(
                    status: RequestStatus.reviewing,
                    includeCompleted: true,
                  ),
                  const Divider(height: 32),
                  _SummaryRow(
                    icon: Icons.photo_library_outlined,
                    label: '完了写真',
                    value: '送信済み',
                  ),
                  const SizedBox(height: 13),
                  const _SummaryRow(
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI完了チェック',
                    value: '86%',
                  ),
                  const SizedBox(height: 13),
                  _SummaryRow(
                    icon: Icons.payments_outlined,
                    label: 'デモ報酬',
                    value: '${formatYen(widget.request.priceYen)}（承認待ち）',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: widget.onToggleMode,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('依頼者画面で確認する'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReward(BuildContext context) {
    return _WorkerPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          children: [
            YukitasScreenHeader(
              mode: UserMode.worker,
              eyebrow: 'YUKITAS',
              title: 'お疲れさまでした',
              subtitle: '報酬と地域貢献',
              onToggleMode: widget.onToggleMode,
            ),
            const SizedBox(height: 26),
            const _CelebrationIcon(icon: Icons.emoji_events_rounded),
            const SizedBox(height: 18),
            const Text(
              'REWARD CONFIRMED',
              style: TextStyle(
                color: YukitasColors.action,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
            const Text(
              '今回の報酬',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(
              formatYen(widget.request.priceYen),
              style: const TextStyle(
                color: YukitasColors.deep,
                fontSize: 55,
                fontWeight: FontWeight.w900,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: YukitasColors.ice,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: YukitasColors.sky),
              ),
              child: const Text(
                'デモ報酬',
                style: TextStyle(
                  color: YukitasColors.action,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _CommunityPointsCard(),
            const SizedBox(height: 16),
            FrostedCard(
              radius: 25,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('あなたの実績', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 13),
                  const Row(
                    children: [
                      Expanded(child: _WorkMetric(label: '除雪件数', value: '33')),
                      SizedBox(width: 8),
                      Expanded(child: _WorkMetric(label: 'SOS支援', value: '5')),
                      SizedBox(width: 8),
                      Expanded(child: _WorkMetric(label: '除雪㎡', value: '428')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GradientActionButton(
              key: const Key('find-next-request'),
              label: '次の依頼を探す',
              icon: Icons.search_rounded,
              workerStyle: true,
              onPressed: widget.onFindNextRequest,
            ),
          ],
        ),
      ),
    );
  }
}

class _AiScoreRing extends StatelessWidget {
  const _AiScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            backgroundColor: YukitasColors.ice,
            color: YukitasColors.safe,
            strokeCap: StrokeCap.round,
          ),
          Text(
            '$score%',
            style: const TextStyle(
              color: YukitasColors.deep,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationIcon extends StatelessWidget {
  const _CelebrationIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 128,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFFB8F4E8), YukitasColors.safe],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x4431C6A6),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 64),
    );
  }
}

class _CommunityPointsCard extends StatelessWidget {
  const _CommunityPointsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE5FBF5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBCEDE1)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white,
            child: Icon(Icons.emoji_events_outlined, color: YukitasColors.safe),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMMUNITY POINTS',
                  style: TextStyle(
                    color: YukitasColors.safe,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  '+120 pt',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                Text(
                  'SOS支援ボーナスを含みます',
                  style: TextStyle(
                    color: YukitasColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerPage extends StatelessWidget {
  const _WorkerPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE7F8FF), YukitasColors.snow],
        ),
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}

class _SafetyCheckTile extends StatelessWidget {
  const _SafetyCheckTile({
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checked ? const Color(0xFFE9FBF6) : const Color(0xEFFFFFFF),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => onChanged(!checked),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: checked ? YukitasColors.safe : YukitasColors.outline,
              width: checked ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: checked ? YukitasColors.safe : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: checked ? YukitasColors.safe : YukitasColors.outline,
                  ),
                ),
                child:
                    checked
                        ? const Icon(Icons.check_rounded, color: Colors.white)
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: YukitasColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: YukitasColors.worker, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: YukitasColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _WorkMetric extends StatelessWidget {
  const _WorkMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: YukitasColors.snow,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: YukitasColors.outline),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: YukitasColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: YukitasColors.deep,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PictureLabel extends StatelessWidget {
  const _PictureLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: YukitasColors.deep,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
