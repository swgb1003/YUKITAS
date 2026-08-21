import 'package:flutter/material.dart';

import '../../domain/requests/snow_request.dart';
import '../theme/yukitas_colors.dart';

/// Short status label used by list rows, where the full sentence-style
/// [RequestStatusPresentation] labels are too long. Status is carried by
/// both color and text so it never depends on color alone (spec 03章
/// アクセシビリティ).
class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip({required this.status, super.key, this.compact = false});

  final RequestStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tone = statusTone(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: tone.border),
      ),
      child: Text(
        tone.label,
        style: TextStyle(
          color: tone.foreground,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class RequestStatusTone {
  const RequestStatusTone({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;
}

RequestStatusTone statusTone(RequestStatus status) => switch (status) {
  RequestStatus.draft => const RequestStatusTone(
    label: '下書き',
    foreground: YukitasColors.muted,
    background: Color(0xFFF1F6F9),
    border: YukitasColors.outline,
  ),
  RequestStatus.waiting => const RequestStatusTone(
    label: '募集中',
    foreground: YukitasColors.deep,
    background: YukitasColors.ice,
    border: YukitasColors.sky,
  ),
  RequestStatus.matched ||
  RequestStatus.moving ||
  RequestStatus.arrived ||
  RequestStatus.working => const RequestStatusTone(
    label: '対応中',
    foreground: Color(0xFF9A6208),
    background: Color(0xFFFFF4E2),
    border: Color(0xFFFFD79B),
  ),
  RequestStatus.reviewing => const RequestStatusTone(
    label: '確認待ち',
    foreground: Color(0xFF9A6208),
    background: Color(0xFFFFF4E2),
    border: Color(0xFFFFD79B),
  ),
  RequestStatus.completed => const RequestStatusTone(
    label: '完了',
    foreground: Color(0xFF0F8E75),
    background: Color(0xFFE9FBF6),
    border: Color(0xFFBCEDE1),
  ),
  RequestStatus.cancelled => const RequestStatusTone(
    label: 'キャンセル',
    foreground: YukitasColors.muted,
    background: Color(0xFFF1F6F9),
    border: YukitasColors.outline,
  ),
  RequestStatus.disputed => const RequestStatusTone(
    label: '要確認',
    foreground: YukitasColors.sos,
    background: Color(0xFFFFEEF2),
    border: Color(0xFFFFB5C4),
  ),
};

/// Small pink "SOS" pill shared by the history and achievement lists.
class SosBadge extends StatelessWidget {
  const SosBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF2),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFFFB5C4)),
      ),
      child: Text(
        'SOS',
        style: TextStyle(
          color: YukitasColors.sos,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
