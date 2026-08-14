import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../application/media/request_photo_service.dart';
import '../../application/requests/estimate_calculator.dart';
import '../../application/requests/snow_analysis_provider.dart';
import '../../core/formatters/yukitas_formatters.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/frosted_card.dart';
import '../../core/widgets/gradient_action_button.dart';
import '../../core/widgets/location_picker_map.dart';
import '../../core/widgets/screen_header.dart';
import '../../core/widgets/snow_map.dart' show niigataCenter;
import '../../domain/places/saved_place.dart';
import '../../domain/requests/snow_request.dart';
import '../../app/app_config.dart';
import '../../app/user_mode.dart';
import 'manual_snow_analysis_sheet.dart';

class RequestCreationFlow extends StatefulWidget {
  const RequestCreationFlow({
    required this.analysisProvider,
    required this.onPublish,
    this.savedPlaces = const <SavedPlace>[],
    this.photoPicker,
    this.photoStorage = const DemoRequestPhotoStorage(),
    this.nearbyWaitingCount = 0,
    super.key,
  });

  final SnowAnalysisProvider analysisProvider;
  final Future<void> Function(SnowRequest request) onPublish;
  final List<SavedPlace> savedPlaces;
  final RequestPhotoPicker? photoPicker;
  final RequestPhotoStorage photoStorage;

  /// Unclaimed (waiting) requests nearby right now - feeds the estimate's
  /// demand surcharge (see EstimateCalculator).
  final int nearbyWaitingCount;

  @override
  State<RequestCreationFlow> createState() => _RequestCreationFlowState();
}

class _RequestCreationFlowState extends State<RequestCreationFlow> {
  static const _imageAsset = 'assets/images/before_driveway.png';
  final _calculator = const EstimateCalculator();
  final Set<String> _workAreas = {'玄関', '駐車場'};
  final String _requestId = 'request-${DateTime.now().microsecondsSinceEpoch}';
  int _step = 0;
  late LatLng _pickedPosition =
      widget.savedPlaces.isNotEmpty
          ? LatLng(
            widget.savedPlaces.first.latitude,
            widget.savedPlaces.first.longitude,
          )
          : niigataCenter;
  late String _pickedAddress =
      widget.savedPlaces.isNotEmpty
          ? widget.savedPlaces.first.approximateAddress
          : '新潟市中央区';
  late SavedPlace? _selectedSavedPlace =
      widget.savedPlaces.isNotEmpty ? widget.savedPlaces.first : null;
  double _areaSqm = 18;
  bool _isSos = true;
  bool _loading = false;
  bool _pickingPhoto = false;
  PickedRequestPhoto? _beforePhoto;
  Uint8List? _beforePreviewBytes;
  String? _uploadedBeforeImagePath;
  SnowAnalysisResult? _analysis;
  RequestEstimate? _estimate;
  bool _isManualEstimate = false;
  String? _analysisError;

  @override
  void initState() {
    super.initState();
    unawaited(_recoverBeforePhoto());
  }

  void _onLocationResolved(PickedLocation picked) {
    setState(() {
      _pickedPosition = picked.position;
      _pickedAddress = picked.address;
      _selectedSavedPlace = picked.savedPlace;
    });
  }

  Future<void> _recoverBeforePhoto() async {
    final picker = widget.photoPicker;
    if (picker == null) return;
    try {
      final photo = await picker.recoverPending();
      if (!mounted || photo == null) return;
      setState(() {
        _beforePhoto = photo;
        _beforePreviewBytes = photo.bytes;
      });
    } on RequestPhotoFailure catch (error) {
      if (mounted) _showPhotoError(error.message);
    }
  }

  Future<void> _pickBeforePhoto(RequestPhotoSource source) async {
    final picker = widget.photoPicker;
    if (picker == null || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final photo = await picker.pick(source);
      if (!mounted || photo == null) return;
      setState(() {
        _beforePhoto = photo;
        _beforePreviewBytes = photo.bytes;
        _uploadedBeforeImagePath = null;
        _analysis = null;
        _estimate = null;
        _analysisError = null;
      });
    } on RequestPhotoFailure catch (error) {
      if (mounted) _showPhotoError(error.message);
    } catch (_) {
      if (mounted) _showPhotoError('写真を選択できませんでした。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _showPhotoError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _analysisError = null;
      _step = 2;
    });
    try {
      final imageReference = await _resolveBeforeImageReference();
      final analysis = await widget.analysisProvider.analyze(
        imageReference: imageReference,
        selectedAreaSqm: _areaSqm,
        workAreas: _workAreas.toList(),
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _estimate = _calculator.calculate(
          analysis,
          nearbyWaitingCount: widget.nearbyWaitingCount,
        );
        _isManualEstimate = false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _analysisError = _analysisErrorMessage(error);
      });
    }
  }

  /// Uploads the picked "before" photo to Storage the first time analysis
  /// runs, then reuses that path for both the AI call and the final
  /// request document - avoiding a duplicate upload at publish time.
  Future<String> _resolveBeforeImageReference() async {
    final uploaded = _uploadedBeforeImagePath;
    if (uploaded != null) return uploaded;
    if (_beforePhoto == null || !widget.photoStorage.usesFirebase) {
      return _imageAsset;
    }
    final path = await widget.photoStorage.upload(
      requestId: _requestId,
      kind: RequestPhotoKind.before,
      photo: _beforePhoto!,
    );
    if (mounted) setState(() => _uploadedBeforeImagePath = path);
    return path;
  }

  String _analysisErrorMessage(Object error) {
    if (error is SnowAnalysisFailure) return error.message;
    if (error is RequestPhotoFailure) return error.message;
    return 'AI解析に失敗しました。通信を確認して再度お試しください。';
  }

  Future<void> _useManualEstimate() async {
    final result = await showManualSnowAnalysisSheet(
      context,
      areaSqm: _areaSqm,
      initial: _analysis,
    );
    if (result == null || !mounted) return;
    setState(() {
      _analysis = result;
      _estimate = _calculator.calculate(
        result,
        nearbyWaitingCount: widget.nearbyWaitingCount,
      );
      _isManualEstimate = true;
      _analysisError = null;
    });
  }

  Future<void> _useSampleAnalysis() async {
    setState(() {
      _loading = true;
      _analysisError = null;
    });
    final analysis = await const DemoSnowAnalysisProvider().analyze(
      imageReference: _imageAsset,
      selectedAreaSqm: _areaSqm,
      workAreas: _workAreas.toList(),
    );
    if (!mounted) return;
    setState(() {
      _analysis = analysis;
      _estimate = _calculator.calculate(
        analysis,
        nearbyWaitingCount: widget.nearbyWaitingCount,
      );
      _isManualEstimate = false;
      _loading = false;
    });
  }

  Future<void> _publish() async {
    final analysis = _analysis;
    final estimate = _estimate;
    if (analysis == null || estimate == null) return;

    setState(() => _loading = true);
    final request = SnowRequest(
      id: _requestId,
      ownerId: 'demo-requester-haruka',
      placeName: _selectedSavedPlace?.label ?? '選択した場所',
      approximateAddress: _pickedAddress,
      latitude: _pickedPosition.latitude,
      longitude: _pickedPosition.longitude,
      workAreas: _workAreas.toList(),
      areaSqm: analysis.areaSqm,
      snowDepthCm: analysis.snowDepthCm,
      difficulty: analysis.difficulty,
      estimatedMinutes: analysis.estimatedMinutes,
      priceYen: estimate.totalYen,
      distanceKm: 0.8,
      isSos: _isSos,
      sosReason: _isSos ? '高齢の家族宅を優先してほしい' : null,
      beforeImageAsset: _uploadedBeforeImagePath ?? _imageAsset,
      status: RequestStatus.waiting,
      createdAt: DateTime.now(),
    );
    try {
      await widget.onPublish(request);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('依頼を公開できませんでした。通信を確認して再度お試しください。')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(request.id);
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_step) {
              0 => _LocationStep(
                key: const ValueKey('request-step-location'),
                initialPosition: _pickedPosition,
                currentAddress: _pickedAddress,
                selectedSavedPlace: _selectedSavedPlace,
                savedPlaces: widget.savedPlaces,
                onLocationResolved: _onLocationResolved,
                onContinue: () => setState(() => _step = 1),
              ),
              1 => _PhotoStep(
                previewBytes: _beforePreviewBytes,
                pickingPhoto: _pickingPhoto,
                photoSelectionEnabled: widget.photoPicker != null,
                photoRequired: widget.photoStorage.usesFirebase,
                areaSqm: _areaSqm,
                workAreas: _workAreas,
                onAreaChanged: (value) => setState(() => _areaSqm = value),
                onAreaToggled: (value) {
                  setState(() {
                    if (!_workAreas.remove(value)) _workAreas.add(value);
                  });
                },
                onAnalyze: _analyze,
                onPickPhoto: _pickBeforePhoto,
              ),
              2 => _AnalysisStep(
                previewBytes: _beforePreviewBytes,
                loading: _loading,
                analysis: _analysis,
                error: _analysisError,
                isManualEstimate: _isManualEstimate,
                showsSampleFallback: AppConfig.showsDemoTools,
                onContinue: () => setState(() => _step = 3),
                onRetry: _analyze,
                onManualEntry: _useManualEstimate,
                onUseSample: _useSampleAnalysis,
                onAdjustValues: _useManualEstimate,
              ),
              _ => _EstimateStep(
                placeLabel: _selectedSavedPlace?.label ?? '選択した場所',
                loading: _loading,
                analysis: _analysis!,
                estimate: _estimate!,
                workAreas: _workAreas,
                isSos: _isSos,
                isManualEstimate: _isManualEstimate,
                onSosChanged: (value) => setState(() => _isSos = value),
                onPublish: _publish,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _CreationHeader extends StatelessWidget {
  const _CreationHeader({
    required this.title,
    required this.subtitle,
    this.step,
  });

  final String title;
  final String subtitle;
  final String? step;

  @override
  Widget build(BuildContext context) {
    return YukitasScreenHeader(
      mode: UserMode.requester,
      title: title,
      subtitle: subtitle,
      eyebrow: step == null ? 'YUKITAS' : 'YUKITAS  •  $step',
      onToggleMode: () {},
      trailing: IconButton.filledTonal(
        key: const Key('close-request-flow'),
        tooltip: '依頼作成を閉じる',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close_rounded),
      ),
    );
  }
}

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.initialPosition,
    required this.currentAddress,
    required this.selectedSavedPlace,
    required this.savedPlaces,
    required this.onLocationResolved,
    required this.onContinue,
    super.key,
  });

  final LatLng initialPosition;
  final String currentAddress;
  final SavedPlace? selectedSavedPlace;
  final List<SavedPlace> savedPlaces;
  final ValueChanged<PickedLocation> onLocationResolved;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final savedPlace = selectedSavedPlace;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          child: const _CreationHeader(
            title: '依頼場所を選ぶ',
            subtitle: '正確な住所は受注後に共有',
            step: 'STEP 1 / 4',
          ),
        ),
        Expanded(
          child: LocationPickerMap(
            initialPosition: initialPosition,
            savedPlaces: savedPlaces,
            onLocationResolved: onLocationResolved,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: FrostedCard(
            padding: const EdgeInsets.all(20),
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SELECTED PLACE',
                  style: TextStyle(
                    color: YukitasColors.action,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                Text(
                  savedPlace?.label ?? currentAddress,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  savedPlace == null
                      ? '地図をタップして場所を調整できます'
                      : [
                        currentAddress,
                        if (savedPlace.beneficiaryName != null)
                          savedPlace.beneficiaryName!,
                        '登録済みの場所',
                      ].join(' • '),
                  style: const TextStyle(
                    color: YukitasColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                GradientActionButton(
                  key: const Key('location-continue'),
                  label: 'この場所で続ける',
                  onPressed: onContinue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoStep extends StatelessWidget {
  const _PhotoStep({
    required this.previewBytes,
    required this.pickingPhoto,
    required this.photoSelectionEnabled,
    required this.photoRequired,
    required this.areaSqm,
    required this.workAreas,
    required this.onAreaChanged,
    required this.onAreaToggled,
    required this.onAnalyze,
    required this.onPickPhoto,
  });

  final Uint8List? previewBytes;
  final bool pickingPhoto;
  final bool photoSelectionEnabled;
  final bool photoRequired;
  final double areaSqm;
  final Set<String> workAreas;
  final ValueChanged<double> onAreaChanged;
  final ValueChanged<String> onAreaToggled;
  final VoidCallback onAnalyze;
  final ValueChanged<RequestPhotoSource> onPickPhoto;

  @override
  Widget build(BuildContext context) {
    const choices = ['玄関', '駐車場', '通路', '車庫前', 'その他'];
    return SingleChildScrollView(
      key: const ValueKey('request-step-photo'),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CreationHeader(
            title: '写真と作業範囲',
            subtitle: '雪の状態と作業箇所を確認',
            step: 'STEP 2 / 4',
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: AspectRatio(
              aspectRatio: 1.46,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (previewBytes != null)
                    Image.memory(previewBytes!, fit: BoxFit.cover)
                  else
                    Image.asset(
                      'assets/images/before_driveway.png',
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
                      child: Text(
                        previewBytes == null ? 'サンプル写真' : '選択済み',
                        style: const TextStyle(
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
          if (photoSelectionEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pick-before-camera'),
                    onPressed:
                        pickingPhoto
                            ? null
                            : () => onPickPhoto(RequestPhotoSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text(
                      '撮影する',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pick-before-gallery'),
                    onPressed:
                        pickingPhoto
                            ? null
                            : () => onPickPhoto(RequestPhotoSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text(
                      '写真を選ぶ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            if (photoRequired && previewBytes == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '依頼を公開するには、現在の雪の写真を追加してください',
                  style: TextStyle(
                    color: YukitasColors.sos,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 14),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            radius: 22,
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: YukitasColors.ice,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: YukitasColors.action,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '撮影ガイド',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '入口と雪の深さが分かる構図です',
                        style: TextStyle(
                          color: YukitasColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'GOOD',
                  style: TextStyle(
                    color: YukitasColors.safe,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text('除雪する場所', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              const Text(
                '複数選択可',
                style: TextStyle(
                  color: YukitasColors.action,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                choices.map((label) {
                  final selected = workAreas.contains(label);
                  return FilterChip(
                    key: Key('work-area-$label'),
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => onAreaToggled(label),
                    selectedColor: YukitasColors.ice,
                    checkmarkColor: YukitasColors.action,
                    side: BorderSide(
                      color:
                          selected ? YukitasColors.sky : YukitasColors.outline,
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('おおよその広さ', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text(
                formatArea(areaSqm),
                style: const TextStyle(
                  color: YukitasColors.action,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            key: const Key('area-slider'),
            value: areaSqm,
            min: 5,
            max: 50,
            divisions: 9,
            onChanged: onAreaChanged,
          ),
          const SizedBox(height: 18),
          GradientActionButton(
            key: const Key('analyze-request'),
            label: 'AIで解析する',
            icon: Icons.auto_awesome_rounded,
            onPressed:
                workAreas.isEmpty || (photoRequired && previewBytes == null)
                    ? null
                    : onAnalyze,
          ),
        ],
      ),
    );
  }
}

class _AnalysisStep extends StatelessWidget {
  const _AnalysisStep({
    required this.previewBytes,
    required this.loading,
    required this.analysis,
    required this.error,
    required this.isManualEstimate,
    required this.showsSampleFallback,
    required this.onContinue,
    required this.onRetry,
    required this.onManualEntry,
    required this.onUseSample,
    required this.onAdjustValues,
  });

  final Uint8List? previewBytes;
  final bool loading;
  final SnowAnalysisResult? analysis;
  final String? error;
  final bool isManualEstimate;
  final bool showsSampleFallback;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final VoidCallback onManualEntry;
  final VoidCallback onUseSample;
  final VoidCallback onAdjustValues;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('request-step-analysis'),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CreationHeader(
            title: 'AI雪量診断',
            subtitle: '写真から作業量を推定',
            step: 'STEP 3 / 4',
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: AspectRatio(
              aspectRatio: 1.45,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (previewBytes != null)
                    Image.memory(previewBytes!, fit: BoxFit.cover)
                  else
                    Image.asset(
                      'assets/images/before_driveway.png',
                      fit: BoxFit.cover,
                    ),
                  const CustomPaint(painter: _AnalysisGridPainter()),
                  if (loading)
                    const ColoredBox(
                      color: Color(0x55075B9B),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FrostedCard(
            padding: const EdgeInsets.all(18),
            radius: 24,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor:
                      error != null ? const Color(0xFFFFEEF2) : YukitasColors.ice,
                  child: Icon(
                    loading
                        ? Icons.hourglass_top_rounded
                        : error != null
                        ? Icons.error_outline_rounded
                        : Icons.auto_awesome_rounded,
                    color: error != null ? YukitasColors.sos : YukitasColors.action,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loading
                            ? 'AIが雪の状態を解析中'
                            : error != null
                            ? 'AI解析に失敗しました'
                            : 'AI解析が完了しました',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        loading
                            ? '写真をアップロードして解析しています'
                            : error != null
                            ? error!
                            : isManualEstimate
                            ? '手入力の内容 • いつでも修正できます'
                            : 'AI解析結果 • 値は修正できます',
                        style: TextStyle(
                          color:
                              error != null
                                  ? YukitasColors.sos
                                  : YukitasColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!loading && analysis != null)
                  isManualEstimate
                      ? const Text(
                        '手入力',
                        style: TextStyle(
                          color: YukitasColors.action,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      )
                      : Text(
                        '${(analysis!.confidence * 100).round()}%',
                        style: const TextStyle(
                          color: YukitasColors.safe,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
              ],
            ),
          ),
          if (!loading && error != null) ...[
            const SizedBox(height: 20),
            GradientActionButton(
              key: const Key('analysis-retry'),
              label: 'もう一度AIで解析する',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('analysis-manual-entry'),
              onPressed: onManualEntry,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('手入力で見積もる'),
            ),
            if (showsSampleFallback) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('analysis-use-sample'),
                onPressed: onUseSample,
                icon: const Icon(Icons.science_outlined),
                label: const Text('サンプル解析を使う（デモ）'),
              ),
            ],
          ],
          if (!loading && analysis != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Text('除雪AI診断', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  key: const Key('analysis-adjust-values'),
                  onPressed: onAdjustValues,
                  child: const Text('値を修正する'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.75,
              children: [
                _MetricCard(
                  label: '推定積雪',
                  value: '${analysis!.snowDepthCm}',
                  unit: 'cm',
                ),
                _MetricCard(
                  label: '作業面積',
                  value: '${analysis!.areaSqm.toInt()}',
                  unit: 'm²',
                ),
                _MetricCard(
                  label: '難易度',
                  value: '${analysis!.difficulty}',
                  unit: '/ 5',
                ),
                _MetricCard(
                  label: '推定時間',
                  value: '${analysis!.estimatedMinutes}',
                  unit: '分',
                ),
              ],
            ),
            const SizedBox(height: 14),
            FrostedCard(
              padding: const EdgeInsets.all(18),
              radius: 22,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '検出した注意点',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          analysis!.hazards.isEmpty
                              ? '特に注意点は検出されませんでした'
                              : analysis!.hazards.join(' • '),
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
                    '${analysis!.hazards.length}件',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GradientActionButton(
              key: const Key('analysis-continue'),
              label: '見積を確認する',
              onPressed: onContinue,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: YukitasColors.ink,
                  fontSize: 29,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstimateStep extends StatelessWidget {
  const _EstimateStep({
    required this.placeLabel,
    required this.loading,
    required this.analysis,
    required this.estimate,
    required this.workAreas,
    required this.isSos,
    required this.isManualEstimate,
    required this.onSosChanged,
    required this.onPublish,
  });

  final String placeLabel;
  final bool loading;
  final SnowAnalysisResult analysis;
  final RequestEstimate estimate;
  final Set<String> workAreas;
  final bool isSos;
  final bool isManualEstimate;
  final ValueChanged<bool> onSosChanged;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('request-step-estimate'),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CreationHeader(
            title: '見積を確認',
            subtitle: 'AIの推定値と料金内訳',
            step: 'STEP 4 / 4',
          ),
          const SizedBox(height: 18),
          FrostedCard(
            padding: const EdgeInsets.all(22),
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RECOMMENDED PRICE',
                  style: TextStyle(
                    color: YukitasColors.action,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatYen(estimate.totalYen),
                        style: const TextStyle(
                          color: YukitasColors.deep,
                          fontSize: 42,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: isManualEstimate ? 1 : analysis.confidence,
                            strokeWidth: 9,
                            backgroundColor: YukitasColors.ice,
                            color:
                                isManualEstimate
                                    ? YukitasColors.action
                                    : YukitasColors.safe,
                          ),
                        ),
                        Text(
                          isManualEstimate
                              ? '手入力'
                              : 'AI\n${(analysis.confidence * 100).round()}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '作業時間 約${analysis.estimatedMinutes}分',
                  style: const TextStyle(
                    color: YukitasColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Divider(height: 30),
                _PriceRow(label: '基本料金', value: estimate.baseFeeYen),
                _PriceRow(
                  label: '作業時間 50円 × ${analysis.estimatedMinutes}分',
                  value: estimate.timeFeeYen,
                ),
                _PriceRow(label: '難易度補正', value: estimate.difficultyFeeYen),
                if (estimate.demandFeeYen > 0)
                  _PriceRow(label: '需要補正', value: estimate.demandFeeYen),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('依頼内容', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          FrostedCard(
            padding: const EdgeInsets.all(18),
            radius: 24,
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: YukitasColors.ice,
                      child: Icon(Icons.location_on_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            placeLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${workAreas.join('・')} / ${formatArea(analysis.areaSqm)}',
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
                const Divider(height: 28),
                SwitchListTile.adaptive(
                  key: const Key('sos-toggle'),
                  contentPadding: EdgeInsets.zero,
                  value: isSos,
                  onChanged: onSosChanged,
                  activeColor: YukitasColors.sos,
                  title: const Text(
                    'SOS除雪',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('緊急通報の代替ではありません'),
                  secondary: const Icon(
                    Icons.warning_amber_rounded,
                    color: YukitasColors.sos,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            radius: 22,
            child: const Row(
              children: [
                Icon(Icons.credit_card_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VISA •••• 4242',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'デモ決済 • 実際の課金は発生しません',
                        style: TextStyle(
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
          ),
          const SizedBox(height: 20),
          GradientActionButton(
            key: const Key('publish-request'),
            label: loading ? '公開しています' : 'この内容で依頼する',
            icon: Icons.auto_awesome_rounded,
            onPressed: loading ? null : onPublish,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            formatYen(value),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _AnalysisGridPainter extends CustomPainter {
  const _AnalysisGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid =
        Paint()
          ..color = YukitasColors.sky.withValues(alpha: 0.34)
          ..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final scan =
        Paint()
          ..color = const Color(0xFF7BE5FF)
          ..strokeWidth = 4;
    canvas.drawLine(
      Offset(20, size.height * 0.18),
      Offset(size.width - 20, size.height * 0.18),
      scan,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
