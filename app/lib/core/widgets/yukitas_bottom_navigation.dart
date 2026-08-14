import 'package:flutter/material.dart';

import '../../app/user_mode.dart';
import '../theme/yukitas_colors.dart';

class YukitasBottomNavigation extends StatelessWidget {
  const YukitasBottomNavigation({
    required this.mode,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final UserMode mode;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items =
        mode == UserMode.requester
            ? const [
              _NavigationItem(Icons.home_outlined, Icons.home_rounded, 'ホーム'),
              _NavigationItem(Icons.map_outlined, Icons.map_rounded, '雪マップ'),
              _NavigationItem(
                Icons.format_list_bulleted,
                Icons.format_list_bulleted_rounded,
                '依頼履歴',
              ),
              _NavigationItem(
                Icons.person_outline,
                Icons.person_rounded,
                'マイページ',
              ),
            ]
            : const [
              _NavigationItem(Icons.map_outlined, Icons.map_rounded, '依頼マップ'),
              _NavigationItem(
                Icons.format_list_bulleted,
                Icons.format_list_bulleted_rounded,
                '依頼一覧',
              ),
              _NavigationItem(
                Icons.emoji_events_outlined,
                Icons.emoji_events_rounded,
                '実績',
              ),
              _NavigationItem(
                Icons.person_outline,
                Icons.person_rounded,
                'マイページ',
              ),
            ];
    final activeColor =
        mode == UserMode.requester
            ? YukitasColors.action
            : YukitasColors.worker;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xF7FFFFFF),
        border: Border(top: BorderSide(color: YukitasColors.outline)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14075B9B),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = currentIndex == index;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  child: InkWell(
                    key: Key('${mode.name}-nav-$index'),
                    onTap: () => onSelected(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 42,
                          height: 34,
                          decoration: BoxDecoration(
                            color:
                                selected
                                    ? activeColor.withValues(alpha: 0.11)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            selected ? item.selectedIcon : item.icon,
                            color: selected ? activeColor : YukitasColors.muted,
                            size: 23,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: selected ? activeColor : YukitasColors.muted,
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
