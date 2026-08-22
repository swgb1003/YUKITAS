import 'package:flutter/material.dart';

import '../../app/user_mode.dart';
import '../../core/formatters/yukitas_formatters.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/mode_switch_button.dart';
import '../../domain/requests/request_summary.dart';

class WorkerListScreen extends StatelessWidget {
  const WorkerListScreen({
    required this.onToggleMode,
    required this.requests,
    required this.onOpenRequest,
    required this.originLatitude,
    required this.originLongitude,
    super.key,
  });

  final VoidCallback onToggleMode;
  final List<RequestSummary> requests;
  final ValueChanged<RequestSummary> onOpenRequest;

  /// The worker's own position, which is where distance is measured from.
  final double originLatitude;
  final double originLongitude;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE5F7FF), YukitasColors.snow],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WORKER MODE',
                          style: TextStyle(
                            color: YukitasColors.action,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '依頼一覧',
                            maxLines: 1,
                            softWrap: false,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ),
                        Text(
                          '${requests.length}件の依頼があります',
                          style: const TextStyle(
                            color: YukitasColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ModeSwitchButton(
                    mode: UserMode.worker,
                    onPressed: onToggleMode,
                  ),
                  const SizedBox(width: 8),
                  const NotificationButton(),
                ],
              ),
              const SizedBox(height: 18),
              const Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _FilterChip(label: '距離が近い', selected: true),
                  _FilterChip(label: '報酬順'),
                  _FilterChip(label: 'SOSのみ', sos: true),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('あなたの近く', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(onPressed: () {}, child: const Text('地図で見る')),
                ],
              ),
              const SizedBox(height: 8),
              if (requests.isEmpty)
                const FrostedCard(child: Center(child: Text('現在、募集中の依頼はありません')))
              else
                for (var index = 0; index < requests.length; index++) ...[
                  _RequestCard(
                    key: Key('worker-request-${requests[index].id}'),
                    request: requests[index],
                    onTap: () => onOpenRequest(requests[index]),
                    distanceKm: requests[index].distanceKmFrom(
                      originLatitude,
                      originLongitude,
                    ),
                  ),
                  if (index != requests.length - 1) const SizedBox(height: 14),
                ],
              const SizedBox(height: 24),
              Text('本日の目安', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              FrostedCard(
                padding: const EdgeInsets.all(18),
                radius: 22,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '活動可能エリア',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '半径 3kmに${requests.length}件',
                            style: const TextStyle(
                              color: YukitasColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: YukitasColors.ice,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: YukitasColors.sky),
                      ),
                      child: Text(
                        '合計 ${formatYen(requests.fold(0, (sum, item) => sum + item.priceYen))}',
                        style: const TextStyle(
                          color: YukitasColors.deep,
                          fontWeight: FontWeight.w800,
                        ),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.selected = false,
    this.sos = false,
  });

  final String label;
  final bool selected;
  final bool sos;

  @override
  Widget build(BuildContext context) {
    final color = sos ? YukitasColors.sos : YukitasColors.action;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:
            sos
                ? const Color(0xFFFFEFF3)
                : selected
                ? YukitasColors.ice
                : const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              selected || sos
                  ? color.withValues(alpha: 0.65)
                  : YukitasColors.outline,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected || sos ? color : YukitasColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Stands where the before photo used to, on the open-requests list.
///
/// The photo is not on the public board: a picture of someone's entrance is
/// exactly what AC-08 keeps away from workers who have not taken the job.
/// The AI's structured read of that photo goes out instead - snow depth is
/// the single most useful number for judging effort, and unlike the image it
/// says nothing about who lives there.
/// Small positive-only indicator for a request's site amenities (parking,
/// tools). Shown only when true - the absence of an amenity is the default
/// and does not need its own badge on an already-dense card; the full
/// detail screen spells out both states before accepting.
class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE9FBF6),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFBCEDE1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: YukitasColors.safe),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: YukitasColors.safe,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobScaleTile extends StatelessWidget {
  const _JobScaleTile({required this.request});

  final RequestSummary request;

  @override
  Widget build(BuildContext context) {
    final sos = request.isSos;
    return Container(
      width: 102,
      height: 106,
      decoration: BoxDecoration(
        color: sos ? const Color(0xFFFFF0F4) : YukitasColors.ice,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: sos ? const Color(0xFFFFC6D2) : YukitasColors.sky,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '積雪',
            style: TextStyle(
              color: YukitasColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: YukitasColors.deep,
                fontWeight: FontWeight.w900,
              ),
              children: [
                TextSpan(
                  text: '${request.snowDepthCm}',
                  style: const TextStyle(fontSize: 30),
                ),
                const TextSpan(text: 'cm', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '約${request.estimatedMinutes}分',
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onTap,
    required this.distanceKm,
    super.key,
  });

  final RequestSummary request;
  final VoidCallback onTap;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final sos = request.isSos;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: FrostedCard(
        padding: const EdgeInsets.all(14),
        radius: 24,
        color: sos ? const Color(0xEFFFF5F7) : const Color(0xEFFFFFFF),
        borderColor: sos ? const Color(0xFFFFBBC8) : Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _JobScaleTile(request: request),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              sos ? const Color(0xFFFFEEF2) : YukitasColors.ice,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color:
                                sos
                                    ? const Color(0xFFFFB5C4)
                                    : YukitasColors.sky,
                          ),
                        ),
                        child: Text(
                          sos ? 'SOS' : '通常',
                          style: TextStyle(
                            color: sos ? YukitasColors.sos : YukitasColors.deep,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatYen(request.priceYen),
                        style: const TextStyle(
                          color: YukitasColors.deep,
                          fontSize: 20,
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
                        Icons.location_on_outlined,
                        size: 16,
                        color: YukitasColors.muted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        formatApproxDistance(distanceKm),
                        style: const TextStyle(
                          color: YukitasColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: YukitasColors.muted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${request.estimatedMinutes}分',
                        style: const TextStyle(
                          color: YukitasColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '作業範囲 ${formatArea(request.areaSqm)} • 難易度 ${request.difficulty}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: YukitasColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (request.parkingAvailable || request.toolsProvided) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (request.parkingAvailable)
                          const _AmenityChip(
                            icon: Icons.local_parking_outlined,
                            label: '駐車可',
                          ),
                        if (request.toolsProvided)
                          const _AmenityChip(
                            icon: Icons.construction_outlined,
                            label: '用具貸与',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
