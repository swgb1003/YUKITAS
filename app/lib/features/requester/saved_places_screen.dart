import 'package:flutter/material.dart';

import '../../app/user_mode.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/screen_header.dart';
import '../../domain/places/saved_place.dart';
import '../../domain/places/saved_place_repository.dart';
import 'saved_place_editor_screen.dart';

/// Full list of the requester's saved places (spec 03章 遠隔家族): manage
/// their own home and any relatives' homes they request on behalf of.
class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({
    required this.repository,
    required this.onToggleMode,
    super.key,
  });

  final SavedPlaceRepository repository;
  final VoidCallback onToggleMode;

  void _openEditor(BuildContext context, {SavedPlace? initial}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => SavedPlaceEditorScreen(
              initial: initial,
              onSave: initial == null ? repository.add : repository.update,
              onDelete: initial == null ? null : repository.remove,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final places = repository.places;
        return Scaffold(
          body: DecoratedBox(
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
                      title: '登録した場所',
                      subtitle:
                          places.isEmpty
                              ? '自宅やご家族の家を登録できます'
                              : '${places.length}件登録済み',
                      onToggleMode: onToggleMode,
                      trailing: IconButton.filledTonal(
                        key: const Key('close-saved-places'),
                        tooltip: '閉じる',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (places.isEmpty)
                      const _EmptyPlaces()
                    else
                      for (var index = 0; index < places.length; index++) ...[
                        _PlaceCard(
                          key: Key('saved-place-${places[index].id}'),
                          place: places[index],
                          onTap:
                              () =>
                                  _openEditor(context, initial: places[index]),
                        ),
                        if (index != places.length - 1)
                          const SizedBox(height: 12),
                      ],
                    const SizedBox(height: 20),
                    GradientActionButton(
                      key: const Key('add-saved-place'),
                      label: '新しい場所を追加',
                      icon: Icons.add_location_alt_outlined,
                      onPressed: () => _openEditor(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onTap, super.key});

  final SavedPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: FrostedCard(
        padding: const EdgeInsets.all(16),
        radius: 24,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: YukitasColors.ice,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.home_outlined,
                color: YukitasColors.action,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.beneficiaryName == null
                        ? place.approximateAddress
                        : '${place.beneficiaryName} • ${place.approximateAddress}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: YukitasColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (place.notifyOnSnowfall) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: YukitasColors.ice,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: YukitasColors.sky),
                      ),
                      child: const Text(
                        '大雪通知の対象',
                        style: TextStyle(
                          color: YukitasColors.deep,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: YukitasColors.muted),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaces extends StatelessWidget {
  const _EmptyPlaces();

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
              Icons.home_outlined,
              size: 34,
              color: YukitasColors.action,
            ),
          ),
          const SizedBox(height: 18),
          Text('まだ場所が登録されていません', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            '自宅や、離れて暮らすご家族の家を登録すると\n依頼作成時にすぐ選べるようになります',
            textAlign: TextAlign.center,
            style: TextStyle(color: YukitasColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
