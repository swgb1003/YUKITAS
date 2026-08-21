import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/user_mode.dart';
import '../../core/formatters/yukitas_formatters.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/mode_switch_button.dart';
import '../../core/widgets/snow_map.dart';
import '../../domain/requests/request_summary.dart';

class WorkerMapScreen extends StatelessWidget {
  const WorkerMapScreen({
    required this.onToggleMode,
    required this.onOpenList,
    required this.requests,
    required this.onOpenRequest,
    required this.originLatitude,
    required this.originLongitude,
    super.key,
  });

  final VoidCallback onToggleMode;
  final VoidCallback onOpenList;
  final List<RequestSummary> requests;
  final ValueChanged<RequestSummary> onOpenRequest;

  /// The worker's own position. Distance is measured from here rather than
  /// read off the request, which used to carry one fixed number for everyone.
  final double originLatitude;
  final double originLongitude;

  RequestSummary? get nearbyRequest => requests.isEmpty ? null : requests.first;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: YukitasColors.ice),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: SnowMap(
                pins: requests.map(MapPin.fromSummary).toList(),
                onTapPin: (id) {
                  for (final request in requests) {
                    if (request.id == id) {
                      onOpenRequest(request);
                      return;
                    }
                  }
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 125,
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
              child: Row(
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
                            '近くの除雪依頼',
                            maxLines: 1,
                            softWrap: false,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        Text(
                          AppConfig.showsDemoTools ? '新潟市中央区 • デモ地点' : '新潟市中央区',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: YukitasColors.muted),
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
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 22,
              child:
                  nearbyRequest == null
                      ? const _EmptyNearbyRequestCard()
                      : _NearbyRequestCard(
                        request: nearbyRequest!,
                        onOpenRequest: onOpenRequest,
                        distanceKm: nearbyRequest!.distanceKmFrom(
                          originLatitude,
                          originLongitude,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNearbyRequestCard extends StatelessWidget {
  const _EmptyNearbyRequestCard();

  @override
  Widget build(BuildContext context) {
    return const FrostedCard(
      padding: EdgeInsets.fromLTRB(20, 22, 20, 22),
      radius: 28,
      child: Column(
        children: [
          Icon(Icons.ac_unit_rounded, color: YukitasColors.action, size: 34),
          SizedBox(height: 10),
          Text(
            '現在、募集中の依頼はありません',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          SizedBox(height: 4),
          Text(
            '新しい依頼が公開されると自動で表示されます',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: YukitasColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyRequestCard extends StatelessWidget {
  const _NearbyRequestCard({
    required this.request,
    required this.onOpenRequest,
    required this.distanceKm,
  });

  final RequestSummary request;
  final ValueChanged<RequestSummary> onOpenRequest;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEARBY REQUEST',
            style: TextStyle(
              color: YukitasColors.action,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.workTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${formatApproxDistance(distanceKm)} • 約${request.estimatedMinutes}分 • 新着',
                      style: const TextStyle(
                        color: YukitasColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatYen(request.priceYen),
                style: const TextStyle(
                  color: YukitasColors.deep,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              _InfoChip(
                icon: Icons.location_on_outlined,
                label: formatApproxDistance(distanceKm),
              ),
              _InfoChip(
                icon: Icons.schedule_rounded,
                label: '${request.estimatedMinutes}分',
              ),
              if (request.isSos) const _InfoChip(label: 'SOS', sos: true),
            ],
          ),
          const SizedBox(height: 16),
          GradientActionButton(
            label: '詳細を見る',
            workerStyle: true,
            onPressed: () => onOpenRequest(request),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.icon, this.sos = false});

  final String label;
  final IconData? icon;
  final bool sos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: sos ? const Color(0xFFFFEFF3) : const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: sos ? const Color(0xFFFFB5C4) : YukitasColors.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: YukitasColors.deep),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: sos ? YukitasColors.sos : YukitasColors.deep,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
