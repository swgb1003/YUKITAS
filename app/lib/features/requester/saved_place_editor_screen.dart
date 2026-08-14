import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/user_mode.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/location_picker_map.dart';
import '../../core/widgets/screen_header.dart';
import '../../core/widgets/snow_map.dart' show niigataCenter;
import '../../domain/places/saved_place.dart';

/// Registers or edits a saved place (spec 03章 遠隔家族): a home the
/// requester can quickly select when creating a request, with an optional
/// beneficiary name for when it's not their own address.
class SavedPlaceEditorScreen extends StatefulWidget {
  const SavedPlaceEditorScreen({
    required this.onSave,
    super.key,
    this.initial,
    this.onDelete,
  });

  final SavedPlace? initial;
  final Future<void> Function(SavedPlace place) onSave;
  final Future<void> Function(String placeId)? onDelete;

  @override
  State<SavedPlaceEditorScreen> createState() =>
      _SavedPlaceEditorScreenState();
}

class _SavedPlaceEditorScreenState extends State<SavedPlaceEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(
    text: widget.initial?.label ?? '',
  );
  late final _beneficiaryController = TextEditingController(
    text: widget.initial?.beneficiaryName ?? '',
  );
  late LatLng _position =
      widget.initial == null
          ? niigataCenter
          : LatLng(widget.initial!.latitude, widget.initial!.longitude);
  late String _address = widget.initial?.approximateAddress ?? '選択した地点';
  late bool _notifyOnSnowfall = widget.initial?.notifyOnSnowfall ?? true;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _labelController.dispose();
    _beneficiaryController.dispose();
    super.dispose();
  }

  void _onLocationResolved(PickedLocation picked) {
    setState(() {
      _position = picked.position;
      _address = picked.address;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    final place = SavedPlace(
      id: widget.initial?.id ?? 'place-${DateTime.now().microsecondsSinceEpoch}',
      label: _labelController.text.trim(),
      approximateAddress: _address,
      latitude: _position.latitude,
      longitude: _position.longitude,
      beneficiaryName:
          _beneficiaryController.text.trim().isEmpty
              ? null
              : _beneficiaryController.text.trim(),
      notifyOnSnowfall: _notifyOnSnowfall,
    );
    try {
      await widget.onSave(place);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存できませんでした。通信を確認して再度お試しください。')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    final initial = widget.initial;
    if (onDelete == null || initial == null || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('${initial.label}を削除しますか？'),
            content: const Text('この場所を依頼作成時に選べなくなります。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('削除'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await onDelete(initial.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('削除できませんでした。もう一度お試しください。')));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
                  child: YukitasScreenHeader(
                    mode: UserMode.requester,
                    eyebrow: 'YUKITAS',
                    title: _isEditing ? '場所を編集' : '家族宅を登録',
                    subtitle: '地図で場所を選んでください',
                    onToggleMode: () {},
                    trailing: IconButton.filledTonal(
                      key: const Key('close-place-editor'),
                      tooltip: '閉じる',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: LocationPickerMap(
                    initialPosition: _position,
                    onLocationResolved: _onLocationResolved,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: FrostedCard(
                    padding: const EdgeInsets.all(20),
                    radius: 28,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 18,
                                color: YukitasColors.action,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: YukitasColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('place-label-field'),
                            controller: _labelController,
                            decoration: const InputDecoration(
                              labelText: '名前',
                              hintText: '例：新潟の実家',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '名前を入力してください';
                              }
                              if (value.trim().length > 30) {
                                return '30文字以内で入力してください';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('place-beneficiary-field'),
                            controller: _beneficiaryController,
                            decoration: const InputDecoration(
                              labelText: '対象者名（任意）',
                              hintText: '例：お母さま',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              if (value != null && value.trim().length > 30) {
                                return '30文字以内で入力してください';
                              }
                              return null;
                            },
                          ),
                          SwitchListTile.adaptive(
                            key: const Key('place-notify-toggle'),
                            contentPadding: EdgeInsets.zero,
                            value: _notifyOnSnowfall,
                            onChanged:
                                (value) =>
                                    setState(() => _notifyOnSnowfall = value),
                            activeColor: YukitasColors.action,
                            title: const Text(
                              '大雪通知を受け取る',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text('この場所への降雪予報をお知らせします'),
                          ),
                          const SizedBox(height: 8),
                          GradientActionButton(
                            key: const Key('save-place'),
                            label: _saving ? '保存しています' : '保存する',
                            onPressed: _saving ? null : _save,
                          ),
                          if (widget.onDelete != null && _isEditing) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton.icon(
                                key: const Key('delete-place'),
                                onPressed: _saving ? null : _delete,
                                style: TextButton.styleFrom(
                                  foregroundColor: YukitasColors.sos,
                                ),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('この場所を削除'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
