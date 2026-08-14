import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/user_mode.dart';
import '../../core/formatters/yukitas_formatters.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/mode_switch_button.dart';
import '../../core/widgets/request_progress_indicator.dart';
import '../../core/widgets/request_photo_image.dart';
import '../../core/widgets/route_map.dart';
import '../../core/widgets/snow_map.dart';
import '../../domain/requests/snow_request.dart';

class RequestStatusScreen extends StatefulWidget {
  const RequestStatusScreen({
    required this.request,
    required this.onToggleMode,
    required this.onApproveCompletion,
    required this.onSubmitRating,
    required this.onFinish,
    super.key,
    this.completedToday = 347,
  });

  final SnowRequest request;
  final VoidCallback onToggleMode;
  final Future<bool> Function() onApproveCompletion;
  final Future<bool> Function(int rating, String? comment) onSubmitRating;
  final VoidCallback onFinish;
  final int completedToday;

  @override
  State<RequestStatusScreen> createState() => _RequestStatusScreenState();
}

class _RequestStatusScreenState extends State<RequestStatusScreen> {
  bool _busy = false;
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController(
    text: '丁寧に作業していただき、ありがとうございました。',
  );

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_busy) return;
    setState(() => _busy = true);
    final succeeded = await widget.onApproveCompletion();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!succeeded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('完了を承認できませんでした')));
    }
  }

  Future<void> _rateAndFinish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final succeeded = await widget.onSubmitRating(
      _rating,
      _commentController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (succeeded) {
      widget.onFinish();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('評価を保存できませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.request.status) {
      RequestStatus.reviewing => _buildCompletionReview(context),
      RequestStatus.completed => _buildCompleted(context),
      _ => _buildProgress(context),
    };
  }

  Widget _buildProgress(BuildContext context) {
    final request = widget.request;
    final hasWorker = request.status != RequestStatus.waiting;
    final showsRoute = request.status == RequestStatus.moving;
    final subtitle = switch (request.status) {
      RequestStatus.waiting => '近くの協力者へ通知しました',
      RequestStatus.matched => '到着予定とプロフィールを確認',
      RequestStatus.moving => '現在地と到着予定を確認できます',
      RequestStatus.arrived => '安全確認後に作業を開始します',
      RequestStatus.working => '作業状況をリアルタイムで共有中',
      _ => '依頼の進捗を確認できます',
    };

    return DecoratedBox(
      decoration: const BoxDecoration(color: YukitasColors.ice),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child:
                  showsRoute
                      ? RouteMap(
                        destination: LatLng(request.latitude, request.longitude),
                        requesterView: true,
                      )
                      : SnowMap(requests: [request]),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 136,
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
              child: _StatusHeader(
                title:
                    request.status == RequestStatus.waiting
                        ? 'ワーカーを検索中'
                        : request.status.requesterLabel,
                subtitle: subtitle,
                onToggleMode: widget.onToggleMode,
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child:
                  hasWorker
                      ? _WorkerProgressCard(request: request)
                      : _MatchingCard(request: request),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionReview(BuildContext context) {
    final request = widget.request;
    return _RequesterPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusHeader(
              title: '完了写真を確認',
              subtitle: 'AI比較は確認を支援します',
              onToggleMode: widget.onToggleMode,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ComparisonPhoto(
                    asset: request.beforeImageAsset,
                    label: 'BEFORE',
                    labelColor: YukitasColors.deep,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ComparisonPhoto(
                    asset: request.afterImageAsset!,
                    label: 'AFTER',
                    labelColor: YukitasColors.safe,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FrostedCard(
              radius: 27,
              child: const Row(
                children: [
                  _AiCompletionRing(),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI COMPLETION CHECK',
                          style: TextStyle(
                            color: YukitasColors.action,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '除雪完了を確認',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '通路確保: 確認\n残雪: 少量・要確認箇所なし',
                          style: TextStyle(
                            color: YukitasColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'AIは参考情報です。最終判断は依頼者が行います。',
                          style: TextStyle(
                            color: YukitasColors.warm,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('ワーカーからの報告', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 9),
            FrostedCard(
              radius: 22,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: YukitasColors.ice,
                    child: Text(
                      (request.workerName ?? '佐').substring(0, 1),
                      style: const TextStyle(
                        color: YukitasColors.deep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      request.workMemo ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('report-completion-problem'),
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (dialogContext) => AlertDialog(
                                title: const Text('問題を報告'),
                                content: const Text(
                                  '写真や作業内容に問題がある場合は、運営が確認します。このデモでは依頼を確認待ちのまま保持します。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(dialogContext).pop(),
                                    child: const Text('閉じる'),
                                  ),
                                ],
                              ),
                        ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    child: const Text('問題を報告'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GradientActionButton(
                    key: const Key('approve-completion'),
                    label: _busy ? '承認しています' : '完了を承認',
                    icon: Icons.check_rounded,
                    workerStyle: true,
                    onPressed: _busy ? null : _approve,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            const Center(
              child: Text(
                '承認するとデモ決済が確定します',
                style: TextStyle(
                  color: YukitasColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleted(BuildContext context) {
    final request = widget.request;
    return _RequesterPage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: Column(
          children: [
            _StatusHeader(
              title: 'ありがとうございました',
              subtitle: '除雪が完了しました',
              onToggleMode: widget.onToggleMode,
            ),
            const SizedBox(height: 23),
            const _MissionCompleteIcon(),
            const SizedBox(height: 15),
            const Text(
              'MISSION COMPLETE',
              style: TextStyle(
                color: YukitasColors.action,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const Text(
              '雪かき、完了です',
              style: TextStyle(
                color: YukitasColors.ink,
                fontSize: 31,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'お母さまのご自宅前が\n安全に通れるようになりました',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: YukitasColors.muted,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FrostedCard(
              radius: 24,
              child: Row(
                children: [
                  const Icon(
                    Icons.credit_card_rounded,
                    color: YukitasColors.deep,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '支払い完了',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'デモ決済・VISA •••• 4242',
                          style: TextStyle(
                            color: YukitasColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatYen(request.priceYen),
                    style: const TextStyle(
                      color: YukitasColors.action,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${request.workerName ?? '佐藤さん'}を評価',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  key: Key('rating-$value'),
                  onPressed: () => setState(() => _rating = value),
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: YukitasColors.warm,
                    size: 42,
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('rating-comment'),
              controller: _commentController,
              minLines: 1,
              maxLines: 2,
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
            const SizedBox(height: 15),
            _LocalImpactCard(completedToday: widget.completedToday),
            const SizedBox(height: 17),
            GradientActionButton(
              key: const Key('rate-and-home'),
              label: _busy ? '評価を保存しています' : '評価してホームへ',
              icon: Icons.home_rounded,
              onPressed: _busy ? null : _rateAndFinish,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequesterPage extends StatelessWidget {
  const _RequesterPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE6F7FF), YukitasColors.snow],
        ),
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.title,
    required this.subtitle,
    required this.onToggleMode,
  });

  final String title;
  final String subtitle;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YUKITAS',
                style: TextStyle(
                  color: YukitasColors.action,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: YukitasColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ModeSwitchButton(mode: UserMode.requester, onPressed: onToggleMode),
        const SizedBox(width: 8),
        const NotificationButton(),
      ],
    );
  }
}

class _ComparisonPhoto extends StatelessWidget {
  const _ComparisonPhoto({
    required this.asset,
    required this.label,
    required this.labelColor,
  });

  final String asset;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 0.75,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RequestPhotoImage(source: asset, fit: BoxFit.cover),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: labelColor,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCompletionRing extends StatelessWidget {
  const _AiCompletionRing();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CircularProgressIndicator(
            value: 0.86,
            strokeWidth: 10,
            backgroundColor: YukitasColors.ice,
            color: YukitasColors.safe,
            strokeCap: StrokeCap.round,
          ),
          const Text(
            '86%',
            style: TextStyle(
              color: YukitasColors.deep,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionCompleteIcon extends StatelessWidget {
  const _MissionCompleteIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      height: 126,
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
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 66),
    );
  }
}

class _LocalImpactCard extends StatelessWidget {
  const _LocalImpactCard({required this.completedToday});

  final int completedToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFE5FBF5),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFBCEDE1)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Icon(Icons.emoji_events_outlined, color: YukitasColors.safe),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LOCAL IMPACT',
                  style: TextStyle(
                    color: YukitasColors.safe,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const Text(
                  '地域の未除雪が1件減りました',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '本日の完了 $completedToday件',
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
    );
  }
}

class _MatchingCard extends StatelessWidget {
  const _MatchingCard({required this.request});
  final SnowRequest request;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.fromLTRB(20, 17, 20, 20),
      radius: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CardHandle(),
          const SizedBox(height: 15),
          const Text(
            'MATCHING',
            style: TextStyle(
              color: YukitasColors.action,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '近くのワーカーを探しています',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const _SearchingDots(),
          const SizedBox(height: 8),
          const Text(
            '通常2〜5分ほどで見つかります',
            style: TextStyle(
              color: YukitasColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              const _StatusChip(label: '半径 3km'),
              _StatusChip(label: '報酬 ${formatYen(request.priceYen)}'),
              if (request.isSos) const _StatusChip(label: 'SOS', sos: true),
            ],
          ),
          const SizedBox(height: 14),
          _PlaceSummary(request: request),
        ],
      ),
    );
  }
}

class _WorkerProgressCard extends StatelessWidget {
  const _WorkerProgressCard({required this.request});
  final SnowRequest request;

  @override
  Widget build(BuildContext context) {
    final isMoving = request.status == RequestStatus.moving;
    final isArrived = request.status == RequestStatus.arrived;
    final isWorking = request.status == RequestStatus.working;
    final badge = switch (request.status) {
      RequestStatus.matched => ('MATCHED', YukitasColors.safe),
      RequestStatus.moving => ('ON THE WAY', YukitasColors.action),
      RequestStatus.arrived => ('ARRIVED', YukitasColors.worker),
      RequestStatus.working => ('WORKING', YukitasColors.worker),
      _ => ('IN PROGRESS', YukitasColors.action),
    };

    return FrostedCard(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 19),
      radius: 29,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CardHandle(),
          const SizedBox(height: 11),
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFE9FBF6),
                child: Text(
                  (request.workerName ?? '佐藤').substring(0, 1),
                  style: const TextStyle(
                    color: YukitasColors.deep,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.workerName ?? '佐藤 拓海さん',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      '評価 4.8 • 除雪実績 32件',
                      style: TextStyle(
                        color: YukitasColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: badge.$2.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  isMoving ? '約8分' : badge.$1,
                  style: TextStyle(
                    color: badge.$2,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RequestProgressIndicator(status: request.status),
          if (isArrived) ...[
            const SizedBox(height: 14),
            const _StatusNotice(
              icon: Icons.verified_user_outlined,
              text: '現地で作業前の安全確認をしています',
            ),
          ],
          if (isWorking) ...[
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(child: _ProgressMetric(label: '作業進捗', value: '68%')),
                SizedBox(width: 9),
                Expanded(child: _ProgressMetric(label: '残り目安', value: '約14分')),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _PlaceSummary(request: request),
        ],
      ),
    );
  }
}

class _PlaceSummary extends StatelessWidget {
  const _PlaceSummary({required this.request});
  final SnowRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: YukitasColors.snow,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: YukitasColors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.home_outlined, color: YukitasColors.deep, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '${request.placeName} • ${request.workAreas.join('・')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            formatArea(request.areaSqm),
            style: const TextStyle(
              color: YukitasColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9FBF6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: YukitasColors.safe, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE9FBF6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: YukitasColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: YukitasColors.deep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHandle extends StatelessWidget {
  const _CardHandle();
  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 5,
    decoration: BoxDecoration(
      color: YukitasColors.outline,
      borderRadius: BorderRadius.circular(99),
    ),
  );
}

class _SearchingDots extends StatefulWidget {
  const _SearchingDots();
  @override
  State<_SearchingDots> createState() => _SearchingDotsState();
}

class _SearchingDotsState extends State<_SearchingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final active = (_controller.value * 3).floor().clamp(0, 2);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: index == active ? 11 : 8,
              height: index == active ? 11 : 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: YukitasColors.sky.withValues(
                  alpha: index == active ? 1 : 0.35,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.sos = false});
  final String label;
  final bool sos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: sos ? const Color(0xFFFFEFF3) : YukitasColors.ice,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: sos ? const Color(0xFFFFB5C4) : YukitasColors.sky,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: sos ? YukitasColors.sos : YukitasColors.deep,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
