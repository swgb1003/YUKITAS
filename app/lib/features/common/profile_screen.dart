import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/user_mode.dart';
import '../../application/requests/worker_achievements.dart';
import '../../core/formatters/yukitas_formatters.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/screen_header.dart';
import '../../domain/places/saved_place.dart';
import '../../domain/requests/snow_request.dart';

/// Shared マイページ for both modes. The header, stats and settings adapt to
/// the active role, but the account itself is one identity across modes
/// (spec 04章: 同一 userId・共通データモデル).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.mode,
    required this.userName,
    required this.ownedRequests,
    required this.achievements,
    required this.onToggleMode,
    super.key,
    this.savedPlaces = const <SavedPlace>[],
    this.onOpenSavedPlaces,
    this.onSignOut,
  });

  final UserMode mode;
  final String userName;
  final List<SnowRequest> ownedRequests;
  final WorkerAchievements achievements;
  final VoidCallback onToggleMode;
  final List<SavedPlace> savedPlaces;
  final VoidCallback? onOpenSavedPlaces;
  final VoidCallback? onSignOut;

  bool get _isWorker => mode == UserMode.worker;

  @override
  Widget build(BuildContext context) {
    final completedOwned =
        ownedRequests
            .where((request) => request.status == RequestStatus.completed)
            .toList();
    final paidYen = completedOwned.fold(0, (sum, r) => sum + r.priceYen);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _isWorker ? const Color(0xFFE7F8FF) : const Color(0xFFE7F7FF),
            YukitasColors.snow,
          ],
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
                mode: mode,
                eyebrow: _isWorker ? 'WORKER MODE' : 'REQUESTER MODE',
                title: 'マイページ',
                subtitle: _isWorker ? 'プロフィールと対応条件' : 'プロフィールと登録情報',
                onToggleMode: onToggleMode,
              ),
              const SizedBox(height: 20),
              _ProfileCard(
                userName: userName,
                mode: mode,
                achievements: achievements,
              ),
              const SizedBox(height: 16),
              Row(
                children:
                    _isWorker
                        ? [
                          Expanded(
                            child: _ProfileStat(
                              value: '${achievements.completedCount}',
                              label: '除雪件数',
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _ProfileStat(
                              value: '${achievements.sosCount}',
                              label: 'SOS支援',
                              color: YukitasColors.sos,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _ProfileStat(
                              value: '${achievements.points}',
                              label: '貢献pt',
                              color: YukitasColors.safe,
                            ),
                          ),
                        ]
                        : [
                          Expanded(
                            child: _ProfileStat(
                              value: '${ownedRequests.length}',
                              label: '依頼した回数',
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _ProfileStat(
                              value: '${completedOwned.length}',
                              label: '完了',
                              color: YukitasColors.safe,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _ProfileStat(
                              value: formatYen(paidYen).replaceAll('円', ''),
                              label: '支払い合計',
                            ),
                          ),
                        ],
              ),
              const SizedBox(height: 22),
              _ModeCard(mode: mode, onToggleMode: onToggleMode),
              const SizedBox(height: 22),
              Text(
                _isWorker ? '対応条件' : '登録した場所',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (_isWorker)
                _SettingsGroup(
                  rows: [
                    _SettingsRow(
                      icon: Icons.travel_explore_rounded,
                      title: '対応エリア',
                      value: '現在地から 3km',
                    ),
                    _SettingsRow(
                      icon: Icons.handyman_outlined,
                      title: '装備',
                      value: 'スコップ・スノーダンプ',
                    ),
                    _SettingsRow(
                      icon: Icons.block_rounded,
                      title: '対象外の作業',
                      value: '屋根雪下ろし・公道・重機',
                      valueColor: YukitasColors.sos,
                    ),
                  ],
                )
              else
                _SettingsGroup(
                  rows: [
                    for (final place in savedPlaces)
                      _SettingsRow(
                        key: Key('profile-saved-place-${place.id}'),
                        icon: Icons.home_outlined,
                        title: place.label,
                        value:
                            place.notifyOnSnowfall
                                ? '大雪通知の対象'
                                : place.approximateAddress,
                        onTap: onOpenSavedPlaces,
                      ),
                    _SettingsRow(
                      key: const Key('profile-manage-places'),
                      icon: Icons.add_location_alt_outlined,
                      title: savedPlaces.isEmpty ? '場所を登録' : '場所を追加・編集',
                      value: '',
                      onTap: onOpenSavedPlaces,
                    ),
                  ],
                ),
              const SizedBox(height: 22),
              Text('設定', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              _SettingsGroup(
                rows: [
                  const _SettingsRow(
                    icon: Icons.notifications_none_rounded,
                    title: '通知設定',
                    value: '新着・受注・完了',
                  ),
                  _SettingsRow(
                    icon: Icons.credit_card_rounded,
                    title: _isWorker ? '受取方法' : '支払い方法',
                    value: 'デモ決済',
                  ),
                  const _SettingsRow(
                    icon: Icons.shield_outlined,
                    title: '安全とプライバシー',
                    value: '住所は受注後に共有',
                  ),
                  const _SettingsRow(
                    icon: Icons.help_outline_rounded,
                    title: 'ヘルプ',
                    value: '',
                  ),
                ],
              ),
              if (onSignOut != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    key: const Key('profile-sign-out'),
                    onPressed: () => _confirmSignOut(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: YukitasColors.sos,
                      side: const BorderSide(color: Color(0xFFFFB5C4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('ログアウト'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: Text(
                  AppConfig.showsDemoTools
                      ? 'YUKITAS プロトタイプ版 • デモデータを含みます'
                      : 'YUKITAS プロトタイプ版',
                  style: const TextStyle(
                    color: YukitasColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('ログアウトしますか？'),
            content: const Text('進行中の依頼がある場合は、完了までログインしたままにしてください。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('ログアウト'),
              ),
            ],
          ),
    );
    if (shouldSignOut == true) onSignOut?.call();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.userName,
    required this.mode,
    required this.achievements,
  });

  final String userName;
  final UserMode mode;
  final WorkerAchievements achievements;

  @override
  Widget build(BuildContext context) {
    final isWorker = mode == UserMode.worker;
    final initial = userName.trim().isEmpty ? 'Y' : userName.trim()[0];
    final rating = achievements.averageRating;

    return FrostedCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      radius: 28,
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isWorker
                        ? const [Color(0xFF39CECC), Color(0xFF1597B6)]
                        : const [YukitasColors.sky, YukitasColors.action],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33168FE0),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isWorker
                                ? const Color(0xFFE4F8FB)
                                : YukitasColors.ice,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color:
                              isWorker
                                  ? const Color(0xFF9FE2EC)
                                  : YukitasColors.sky,
                        ),
                      ),
                      child: Text(
                        isWorker ? 'ワーカー' : '依頼者',
                        style: TextStyle(
                          color:
                              isWorker
                                  ? YukitasColors.worker
                                  : YukitasColors.deep,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isWorker && rating != null) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.star_rounded,
                        size: 17,
                        color: YukitasColors.warm,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        ' (${achievements.ratingCount})',
                        style: const TextStyle(
                          color: YukitasColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isWorker
                      ? '地域貢献 Lv.${achievements.level}'
                      : '新潟市中央区で利用中',
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
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
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
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 22,
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onToggleMode});

  final UserMode mode;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final isWorker = mode == UserMode.worker;
    return FrostedCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isWorker ? const Color(0xFFE4F8FB) : YukitasColors.ice,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isWorker ? Icons.snowing : Icons.home_outlined,
              color: isWorker ? YukitasColors.worker : YukitasColors.action,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWorker ? '作業する（ワーカー）' : '依頼する（依頼者）',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Text(
                  '同じアカウントで切り替えられます',
                  style: TextStyle(
                    color: YukitasColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('profile-toggle-mode'),
            onPressed: onToggleMode,
            child: Text(isWorker ? '依頼者へ' : 'ワーカーへ'),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<_SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      radius: 24,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1)
              const Divider(height: 1, indent: 14, endIndent: 14),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
    super.key,
    this.valueColor = YukitasColors.muted,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap:
          onTap ??
          () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$titleは準備中です')),
          ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 15, 10, 15),
        child: Row(
          children: [
            Icon(icon, size: 21, color: YukitasColors.action),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (value.isNotEmpty)
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: YukitasColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
