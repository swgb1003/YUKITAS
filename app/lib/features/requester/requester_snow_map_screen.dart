import 'package:flutter/material.dart';

import '../../app/user_mode.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/mode_switch_button.dart';
import '../../core/widgets/snow_map.dart';
import '../../domain/requests/request_summary.dart';
import '../../domain/requests/snow_request.dart';

/// Real-map version of R-01/06章の地域雪マップ: shows nearby requests
/// color-coded by status, with a legend explaining what each color means.
///
/// Draws from the public board, so every pin sits at a cell center rather
/// than a front door (spec 06.1 "個人宅の正確な位置は受注前に公開せず").
class RequesterSnowMapScreen extends StatelessWidget {
  const RequesterSnowMapScreen({
    required this.requests,
    required this.onToggleMode,
    super.key,
  });

  final List<RequestSummary> requests;
  final VoidCallback onToggleMode;

  bool _isActive(RequestStatus status) =>
      status == RequestStatus.matched ||
      status == RequestStatus.moving ||
      status == RequestStatus.arrived ||
      status == RequestStatus.working ||
      status == RequestStatus.reviewing;

  @override
  Widget build(BuildContext context) {
    final waiting =
        requests.where((r) => r.status == RequestStatus.waiting).length;
    final active = requests.where((r) => _isActive(r.status)).length;
    final sos = requests.where((r) => r.isSos).length;

    return DecoratedBox(
      decoration: const BoxDecoration(color: YukitasColors.ice),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: SnowMap(
                pins: requests.map(MapPin.fromSummary).toList(),
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
                          'REQUESTER MODE',
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
                            '地域雪マップ',
                            maxLines: 1,
                            softWrap: false,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const Text(
                          '募集中・対応中を色で表示',
                          style: TextStyle(
                            color: YukitasColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ModeSwitchButton(
                    mode: UserMode.requester,
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
              child: FrostedCard(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                radius: 26,
                child: Row(
                  children: [
                    _LegendItem(
                      color: snowMapWaitingColor,
                      label: '募集中',
                      count: waiting,
                    ),
                    _LegendItem(
                      color: snowMapActiveColor,
                      label: '対応中',
                      count: active,
                    ),
                    _LegendItem(
                      color: snowMapSosColor,
                      label: 'SOS',
                      count: sos,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SnowMapLegendDot(color: color),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      color: YukitasColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: YukitasColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
