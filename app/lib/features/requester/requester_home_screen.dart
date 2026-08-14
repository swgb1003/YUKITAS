import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/user_mode.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/mode_switch_button.dart';
import '../../core/widgets/snow_map.dart';
import '../../domain/requests/snow_request.dart';
import '../../domain/stats/region_stats.dart';

class RequesterHomeScreen extends StatelessWidget {
  const RequesterHomeScreen({
    required this.onToggleMode,
    required this.onCreateRequest,
    required this.requests,
    required this.onOpenSnowMap,
    super.key,
    this.stats = RegionStats.demo,
  });

  final VoidCallback onToggleMode;
  final VoidCallback onCreateRequest;
  final List<SnowRequest> requests;
  final VoidCallback onOpenSnowMap;
  final RegionStats stats;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            children: [
              _WeatherHero(
                onToggleMode: onToggleMode,
                onCreateRequest: onCreateRequest,
                stats: stats,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '地域雪マップ',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: onOpenSnowMap,
                          child: const Text('全体を見る'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 230,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: YukitasColors.outline),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14075B9B),
                            blurRadius: 18,
                            offset: Offset(0, 9),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: onOpenSnowMap,
                        child: SnowMap(
                          compact: true,
                          requests: requests,
                          interactive: false,
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

class _WeatherHero extends StatelessWidget {
  const _WeatherHero({
    required this.onToggleMode,
    required this.onCreateRequest,
    required this.stats,
  });

  final RegionStats stats;
  final VoidCallback onToggleMode;
  final VoidCallback onCreateRequest;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 530,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/snow_town_hero.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFF2FAFE),
                    Color(0xD9F2FAFE),
                    Color(0x00F2FAFE),
                  ],
                  stops: [0, 0.42, 0.82],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00F7FBFE),
                    Color(0x00F7FBFE),
                    YukitasColors.snow,
                  ],
                  stops: [0, 0.7, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: 12,
            child: Row(
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
                          letterSpacing: 1.7,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'おはようございます',
                          maxLines: 1,
                          softWrap: false,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      Text(
                        AppConfig.showsDemoTools
                            ? '遥さん / 新潟市中央区 • DEMO'
                            : '遥さん / 新潟市中央区',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: YukitasColors.muted,
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
            left: 24,
            top: 118,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.displayLarge,
                    children: [
                      const TextSpan(text: '-2'),
                      TextSpan(
                        text: '℃',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '明朝、30cmの\n降雪予報です',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 10),
                Text(
                  '登録したご実家周辺で\n大雪が予想されています',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF54748A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: FrostedCard(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              radius: 28,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '${stats.completedToday}',
                          label: '本日完了',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '${stats.sosSupportedToday}',
                          label: 'SOS支援',
                          sos: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '${stats.activeNow}',
                          label: '活動中',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GradientActionButton(
                    key: const Key('create-request'),
                    label: '雪かきを依頼する',
                    icon: Icons.add_rounded,
                    onPressed: onCreateRequest,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.sos = false});

  final String value;
  final String label;
  final bool sos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xC9FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14075B9B),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: sos ? YukitasColors.sos : YukitasColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
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
