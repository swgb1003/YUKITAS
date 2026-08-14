import 'package:flutter/material.dart';

import '../../app/user_mode.dart';
import '../../core/formatters/yukitas_formatters.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/request_photo_image.dart';
import '../../core/widgets/request_status_chip.dart';
import '../../core/widgets/screen_header.dart';
import '../../domain/requests/snow_request.dart';

enum _HistoryFilter { all, active, completed }

/// R-01 supporting screen: everything the requester has asked for, newest
/// first. Completed entries keep their Before / After evidence so a remote
/// family member can re-check the result long after the worker left.
class RequestHistoryScreen extends StatefulWidget {
  const RequestHistoryScreen({
    required this.requests,
    required this.onToggleMode,
    required this.onCreateRequest,
    super.key,
  });

  final List<SnowRequest> requests;
  final VoidCallback onToggleMode;
  final VoidCallback onCreateRequest;

  @override
  State<RequestHistoryScreen> createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends State<RequestHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  bool _isActive(RequestStatus status) =>
      status != RequestStatus.completed &&
      status != RequestStatus.cancelled &&
      status != RequestStatus.draft;

  List<SnowRequest> get _visibleRequests => switch (_filter) {
    _HistoryFilter.all => widget.requests,
    _HistoryFilter.active =>
      widget.requests.where((r) => _isActive(r.status)).toList(),
    _HistoryFilter.completed =>
      widget.requests
          .where((r) => r.status == RequestStatus.completed)
          .toList(),
  };

  @override
  Widget build(BuildContext context) {
    final requests = widget.requests;
    final completed =
        requests.where((r) => r.status == RequestStatus.completed).toList();
    final activeCount = requests.where((r) => _isActive(r.status)).length;
    final totalPaidYen = completed.fold(0, (sum, r) => sum + r.priceYen);
    final visible = _visibleRequests;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE7F7FF), YukitasColors.snow],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YukitasScreenHeader(
                mode: UserMode.requester,
                eyebrow: 'REQUESTER MODE',
                title: '依頼履歴',
                subtitle:
                    requests.isEmpty
                        ? 'これまでの依頼がここに並びます'
                        : '${requests.length}件の依頼 • 完了 ${completed.length}件',
                onToggleMode: widget.onToggleMode,
              ),
              const SizedBox(height: 18),
              FrostedCard(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                radius: 26,
                child: Row(
                  children: [
                    _SummaryStat(
                      value: '${requests.length}',
                      label: '依頼した回数',
                      unit: '件',
                    ),
                    _SummaryStat(
                      value: '$activeCount',
                      label: '進行中',
                      unit: '件',
                      color: YukitasColors.warm,
                    ),
                    _SummaryStat(
                      value: formatYen(totalPaidYen).replaceAll('円', ''),
                      label: '支払い合計',
                      unit: '円',
                      color: YukitasColors.safe,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (final filter in _HistoryFilter.values) ...[
                    _FilterChip(
                      key: Key('history-filter-${filter.name}'),
                      label: switch (filter) {
                        _HistoryFilter.all => 'すべて',
                        _HistoryFilter.active => '進行中',
                        _HistoryFilter.completed => '完了',
                      },
                      selected: _filter == filter,
                      onTap: () => setState(() => _filter = filter),
                    ),
                    if (filter != _HistoryFilter.values.last)
                      const SizedBox(width: 9),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              if (visible.isEmpty)
                _EmptyHistory(
                  hasAnyRequest: requests.isNotEmpty,
                  onCreateRequest: widget.onCreateRequest,
                )
              else
                for (var index = 0; index < visible.length; index++) ...[
                  _HistoryCard(
                    key: Key('history-request-${visible[index].id}'),
                    request: visible[index],
                    onTap: () => _showDetail(visible[index]),
                  ),
                  if (index != visible.length - 1) const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(SnowRequest request) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HistoryDetailSheet(request: request),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.value,
    required this.label,
    required this.unit,
    this.color = YukitasColors.ink,
  });

  final String value;
  final String label;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  color: YukitasColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: YukitasColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? YukitasColors.ice : const Color(0xD9FFFFFF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected
                      ? YukitasColors.action.withValues(alpha: 0.65)
                      : YukitasColors.outline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? YukitasColors.action : YukitasColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.request, required this.onTap, super.key});

  final SnowRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timestamp = request.completedAt ?? request.createdAt;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: FrostedCard(
        padding: const EdgeInsets.all(14),
        radius: 24,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: RequestPhotoImage(
                source: request.afterImageAsset ?? request.beforeImageAsset,
                width: 92,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RequestStatusChip(status: request.status),
                      if (request.isSos) ...[
                        const SizedBox(width: 6),
                        const SosBadge(),
                      ],
                      const Spacer(),
                      Text(
                        formatYen(request.priceYen),
                        style: const TextStyle(
                          color: YukitasColors.deep,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    request.workTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 15,
                        color: YukitasColors.muted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          request.placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: YukitasColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        formatRelativeDate(timestamp),
                        style: const TextStyle(
                          color: YukitasColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    request.workerName == null
                        ? '積雪 約${request.snowDepthCm}cm • ${formatArea(request.areaSqm)}'
                        : '${request.workerName} • ${formatArea(request.areaSqm)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: YukitasColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({
    required this.hasAnyRequest,
    required this.onCreateRequest,
  });

  final bool hasAnyRequest;
  final VoidCallback onCreateRequest;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      radius: 26,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: YukitasColors.ice,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.ac_unit_rounded,
              size: 34,
              color: YukitasColors.action,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasAnyRequest ? '該当する依頼はありません' : 'まだ依頼はありません',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            hasAnyRequest
                ? '他の絞り込みを試してみてください'
                : '雪かきを依頼すると、進捗と完了写真が\nここに残ります',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: YukitasColors.muted,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!hasAnyRequest) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              key: const Key('history-create-request'),
              onPressed: onCreateRequest,
              icon: const Icon(Icons.add_rounded),
              label: const Text('雪かきを依頼する'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryDetailSheet extends StatelessWidget {
  const _HistoryDetailSheet({required this.request});

  final SnowRequest request;

  @override
  Widget build(BuildContext context) {
    final afterImage = request.afterImageAsset;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: YukitasColors.snow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: YukitasColors.outline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  RequestStatusChip(status: request.status),
                  if (request.isSos) ...[
                    const SizedBox(width: 6),
                    const SosBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                request.workTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '${request.placeName} • ${formatDateTime(request.createdAt)}',
                style: const TextStyle(
                  color: YukitasColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (afterImage == null)
                _SheetPhoto(
                  source: request.beforeImageAsset,
                  label: 'BEFORE',
                  labelColor: YukitasColors.deep,
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _SheetPhoto(
                        source: request.beforeImageAsset,
                        label: 'BEFORE',
                        labelColor: YukitasColors.deep,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SheetPhoto(
                        source: afterImage,
                        label: 'AFTER',
                        labelColor: YukitasColors.safe,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              FrostedCard(
                radius: 24,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.payments_outlined,
                      label: '料金',
                      value: formatYen(request.priceYen),
                    ),
                    const Divider(height: 22),
                    _DetailRow(
                      icon: Icons.straighten_rounded,
                      label: '作業範囲',
                      value:
                          '${formatArea(request.areaSqm)} • 積雪 約${request.snowDepthCm}cm',
                    ),
                    const Divider(height: 22),
                    _DetailRow(
                      icon: Icons.schedule_rounded,
                      label: '作業目安',
                      value: '約${request.estimatedMinutes}分',
                    ),
                    if (request.workerName != null) ...[
                      const Divider(height: 22),
                      _DetailRow(
                        icon: Icons.person_outline_rounded,
                        label: '担当ワーカー',
                        value: request.workerName!,
                      ),
                    ],
                    if (request.completedAt != null) ...[
                      const Divider(height: 22),
                      _DetailRow(
                        icon: Icons.check_circle_outline_rounded,
                        label: '完了日時',
                        value: formatDateTime(request.completedAt!),
                      ),
                    ],
                  ],
                ),
              ),
              if (request.workMemo != null) ...[
                const SizedBox(height: 16),
                Text('作業メモ', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                FrostedCard(
                  radius: 22,
                  child: Text(
                    request.workMemo!,
                    style: const TextStyle(height: 1.6),
                  ),
                ),
              ],
              if (request.rating != null) ...[
                const SizedBox(height: 16),
                Text('あなたの評価', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                FrostedCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var star = 1; star <= 5; star++)
                            Icon(
                              star <= request.rating!
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: YukitasColors.warm,
                              size: 26,
                            ),
                        ],
                      ),
                      if (request.ratingComment != null &&
                          request.ratingComment!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          request.ratingComment!,
                          style: const TextStyle(
                            color: YukitasColors.muted,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SheetPhoto extends StatelessWidget {
  const _SheetPhoto({
    required this.source,
    required this.label,
    required this.labelColor,
  });

  final String source;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 1.2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RequestPhotoImage(source: source, fit: BoxFit.cover),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xEFFFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
        Icon(icon, size: 20, color: YukitasColors.action),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: YukitasColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
