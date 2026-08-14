import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/user_mode.dart';
import '../../core/formatters/yukitas_formatters.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/request_photo_image.dart';
import '../../core/widgets/screen_header.dart';
import '../../domain/requests/snow_request.dart';

class WorkerRequestDetailScreen extends StatefulWidget {
  const WorkerRequestDetailScreen({
    required this.request,
    required this.onAccept,
    super.key,
  });

  final SnowRequest request;
  final Future<bool> Function() onAccept;

  @override
  State<WorkerRequestDetailScreen> createState() =>
      _WorkerRequestDetailScreenState();
}

class _WorkerRequestDetailScreenState extends State<WorkerRequestDetailScreen> {
  bool _accepting = false;

  Future<void> _showConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x990B2E47),
      builder:
          (dialogContext) => RepaintBoundary(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Dialog(
                insetPadding: const EdgeInsets.all(22),
                backgroundColor: Colors.transparent,
                child: FrostedCard(
                  padding: const EdgeInsets.all(24),
                  radius: 30,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: YukitasColors.ice,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: YukitasColors.worker,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ACCEPT REQUEST',
                        style: TextStyle(
                          color: YukitasColors.action,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                      Text(
                        'この依頼を受けますか？',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '受注後、依頼者にプロフィールと\n到着予定時刻が共有されます',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: YukitasColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: YukitasColors.snow,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(color: YukitasColors.outline),
                        ),
                        child: Column(
                          children: [
                            _ConfirmRow(
                              label: '報酬',
                              value: formatYen(widget.request.priceYen),
                              emphasized: true,
                            ),
                            const Divider(height: 22),
                            _ConfirmRow(
                              label: '目安時間',
                              value: '約${widget.request.estimatedMinutes}分',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9FBF6),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: YukitasColors.safe,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '屋根・公道・重機作業は行いません',
                                style: TextStyle(fontWeight: FontWeight.w700),
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
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(false),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text('戻る'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              key: const Key('confirm-accept-request'),
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(true),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                backgroundColor: YukitasColors.worker,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text(
                                '受注を確定',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _accepting = true);
    final accepted = await widget.onAccept();
    if (!mounted) return;
    setState(() => _accepting = false);
    if (accepted) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('この依頼はすでに受注されました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F7FF), YukitasColors.snow],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                YukitasScreenHeader(
                  mode: UserMode.worker,
                  title: '依頼詳細',
                  subtitle: '受注前は概略位置を表示',
                  onToggleMode: () {},
                  trailing: IconButton.filledTonal(
                    tooltip: '依頼一覧へ戻る',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: AspectRatio(
                    aspectRatio: 1.35,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RequestPhotoImage(
                          source: request.beforeImageAsset,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          left: 14,
                          top: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xEFFFFFFF),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'BEFORE',
                              style: TextStyle(
                                color: YukitasColors.deep,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FrostedCard(
                      padding: const EdgeInsets.all(18),
                      radius: 25,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (request.isSos)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEFF3),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: const Color(0xFFFFB5C4),
                                ),
                              ),
                              child: const Text(
                                'SOS除雪',
                                style: TextStyle(
                                  color: YukitasColors.sos,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request.workTitle,
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                    ),
                                    Text(
                                      '${request.approximateAddress} • ${request.distanceKm}km',
                                      style: const TextStyle(
                                        color: YukitasColors.muted,
                                        fontSize: 12,
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
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Text('作業の目安', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DetailMetric(
                        label: '推定積雪',
                        value: '${request.snowDepthCm} cm',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DetailMetric(
                        label: '所要時間',
                        value: '${request.estimatedMinutes} 分',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FrostedCard(
                  padding: const EdgeInsets.all(18),
                  radius: 23,
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        title:
                            '${request.workAreas.join('・')} / ${formatArea(request.areaSqm)}',
                        subtitle: '雪は敷地右側へまとめる',
                      ),
                      const Divider(height: 26),
                      const _DetailRow(
                        icon: Icons.warning_amber_rounded,
                        title: '門扉付近に段差あり',
                        subtitle: '屋根・公道作業は対象外',
                        warning: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GradientActionButton(
                  key: const Key('accept-request'),
                  label: _accepting ? '受注を確定しています' : 'この依頼を受ける',
                  workerStyle: true,
                  onPressed:
                      _accepting || !request.isAvailable
                          ? null
                          : _showConfirmation,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: YukitasColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasized ? YukitasColors.action : YukitasColors.ink,
            fontSize: emphasized ? 22 : 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.all(17),
      radius: 21,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: YukitasColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor:
              warning ? const Color(0xFFFFF5E8) : YukitasColors.ice,
          child: Icon(
            icon,
            color: warning ? YukitasColors.warm : YukitasColors.deep,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
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
    );
  }
}
