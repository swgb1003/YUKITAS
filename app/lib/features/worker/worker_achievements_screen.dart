import 'package:flutter/material.dart';

import '../../app/user_mode.dart';
import '../../application/requests/worker_achievements.dart';
import '../../core/formatters/yukitas_formatters.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/request_photo_image.dart';
import '../../core/widgets/request_status_chip.dart';
import '../../core/widgets/screen_header.dart';
import '../../domain/requests/snow_request.dart';

/// W-09 as a standing tab: how much this worker has contributed to the
/// area, expressed in jobs, SOS support, cleared area and contribution
/// points rather than earnings alone (spec 03章 地域貢献).
class WorkerAchievementsScreen extends StatelessWidget {
  const WorkerAchievementsScreen({
    required this.achievements,
    required this.recentRequests,
    required this.onToggleMode,
    required this.onFindWork,
    super.key,
  });

  final WorkerAchievements achievements;
  final List<SnowRequest> recentRequests;
  final VoidCallback onToggleMode;
  final VoidCallback onFindWork;

  @override
  Widget build(BuildContext context) {
    final completedRequests =
        recentRequests
            .where((request) => request.status == RequestStatus.completed)
            .take(4)
            .toList();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE7F8FF), YukitasColors.snow],
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
                mode: UserMode.worker,
                eyebrow: 'WORKER MODE',
                title: '実績',
                subtitle: 'あなたが地域に届けた成果',
                onToggleMode: onToggleMode,
              ),
              const SizedBox(height: 22),
              _PointsHero(achievements: achievements),
              const SizedBox(height: 16),
              _LevelCard(achievements: achievements),
              const SizedBox(height: 20),
              Text('あなたの実績', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AchievementStat(
                      value: '${achievements.completedCount}',
                      label: '除雪件数',
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _AchievementStat(
                      value: '${achievements.sosCount}',
                      label: 'SOS支援',
                      color: YukitasColors.sos,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _AchievementStat(
                      value: '${achievements.areaSqm.round()}',
                      label: '除雪 m²',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FrostedCard(
                padding: const EdgeInsets.all(18),
                radius: 24,
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: YukitasColors.ice,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: YukitasColors.action,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '累計報酬',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            achievements.ratingCount == 0
                                ? 'デモ決済のみ・実際の入金はありません'
                                : '評価 ${achievements.averageRating!.toStringAsFixed(1)} / ${achievements.ratingCount}件',
                            style: const TextStyle(
                              color: YukitasColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatYen(achievements.earningsYen),
                      style: const TextStyle(
                        color: YukitasColors.deep,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('最近の作業', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (completedRequests.isEmpty)
                _NoCompletedWorkCard(onFindWork: onFindWork)
              else
                for (var index = 0; index < completedRequests.length; index++) ...[
                  _CompletedWorkRow(request: completedRequests[index]),
                  if (index != completedRequests.length - 1)
                    const SizedBox(height: 10),
                ],
              if (achievements.includesDemoBaseline) ...[
                const SizedBox(height: 18),
                const _DemoBaselineNotice(),
              ],
              const SizedBox(height: 20),
              GradientActionButton(
                key: const Key('achievements-find-work'),
                label: '次の依頼を探す',
                icon: Icons.search_rounded,
                workerStyle: true,
                onPressed: onFindWork,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsHero extends StatelessWidget {
  const _PointsHero({required this.achievements});

  final WorkerAchievements achievements;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE5FBF5), Color(0xFFD6F4FA)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFBCEDE1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2231C6A6),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFFB8F4E8), YukitasColors.safe],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x4431C6A6),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMMUNITY POINTS',
                  style: TextStyle(
                    color: Color(0xFF0F8E75),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${achievements.points}',
                      style: const TextStyle(
                        color: YukitasColors.ink,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'pt',
                      style: TextStyle(
                        color: YukitasColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Text(
                  '完了1件で100pt・SOS支援で+20pt',
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

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.achievements});

  final WorkerAchievements achievements;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      radius: 24,
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
                    Text(
                      '地域貢献 Lv.${achievements.level}',
                      style: const TextStyle(
                        color: YukitasColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '次のレベルまで ${achievements.pointsToNextLevel}pt',
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
                '${(achievements.levelProgress * 100).round()}%',
                style: const TextStyle(
                  color: YukitasColors.action,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label:
                '地域貢献レベル${achievements.level}、次のレベルまで${achievements.pointsToNextLevel}ポイント',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: achievements.levelProgress,
                minHeight: 10,
                backgroundColor: YukitasColors.ice,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  YukitasColors.sky,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementStat extends StatelessWidget {
  const _AchievementStat({
    required this.value,
    required this.label,
    this.color = YukitasColors.ink,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14075B9B),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
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

class _CompletedWorkRow extends StatelessWidget {
  const _CompletedWorkRow({required this.request});

  final SnowRequest request;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.all(12),
      radius: 22,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: RequestPhotoImage(
              source: request.afterImageAsset ?? request.beforeImageAsset,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        request.workTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (request.isSos) ...[
                      const SizedBox(width: 6),
                      const SosBadge(compact: true),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatArea(request.areaSqm)} • ${formatRelativeDate(request.completedAt ?? request.createdAt)}',
                  style: const TextStyle(
                    color: YukitasColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatYen(request.priceYen),
                style: const TextStyle(
                  color: YukitasColors.deep,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '+${WorkerAchievements.pointsPerJob + (request.isSos ? WorkerAchievements.sosBonusPoints : 0)}pt',
                style: const TextStyle(
                  color: YukitasColors.safe,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoCompletedWorkCard extends StatelessWidget {
  const _NoCompletedWorkCard({required this.onFindWork});

  final VoidCallback onFindWork;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      radius: 24,
      child: Column(
        children: [
          const Icon(
            Icons.snowing,
            size: 34,
            color: YukitasColors.worker,
          ),
          const SizedBox(height: 12),
          Text(
            'まだ完了した作業はありません',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          const Text(
            '近くの依頼を受注すると、ここに実績が残ります',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: YukitasColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('achievements-empty-find-work'),
            onPressed: onFindWork,
            icon: const Icon(Icons.search_rounded),
            label: const Text('依頼を探す'),
          ),
        ],
      ),
    );
  }
}

class _DemoBaselineNotice extends StatelessWidget {
  const _DemoBaselineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: YukitasColors.ice,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: YukitasColors.outline),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: YukitasColors.action),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '過去の活動分としてデモ実績を含めて集計しています',
              style: TextStyle(
                color: YukitasColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
