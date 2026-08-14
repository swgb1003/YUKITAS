import 'package:flutter/material.dart';

import '../../application/requests/snow_analysis_provider.dart';
import '../../core/theme/yukitas_colors.dart';
import '../../core/widgets/gradient_action_button.dart';

/// Manual fallback for the AI estimate (spec 05章 エラー・フォールバック): lets the
/// requester enter snow depth / difficulty / work time by eye when analysis
/// fails, or adjust the AI's values directly when its confidence is low.
Future<SnowAnalysisResult?> showManualSnowAnalysisSheet(
  BuildContext context, {
  required double areaSqm,
  SnowAnalysisResult? initial,
}) {
  return showModalBottomSheet<SnowAnalysisResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) =>
            _ManualSnowAnalysisSheet(areaSqm: areaSqm, initial: initial),
  );
}

class _ManualSnowAnalysisSheet extends StatefulWidget {
  const _ManualSnowAnalysisSheet({required this.areaSqm, this.initial});

  final double areaSqm;
  final SnowAnalysisResult? initial;

  @override
  State<_ManualSnowAnalysisSheet> createState() =>
      _ManualSnowAnalysisSheetState();
}

class _ManualSnowAnalysisSheetState extends State<_ManualSnowAnalysisSheet> {
  late double _snowDepthCm = (widget.initial?.snowDepthCm ?? 20).toDouble();
  late double _difficulty = (widget.initial?.difficulty ?? 3).toDouble();
  late double _estimatedMinutes =
      (widget.initial?.estimatedMinutes ?? 40).toDouble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: YukitasColors.snow,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: YukitasColors.outline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '見積り内容を手入力',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '写真を見て、おおよその値を入力してください',
                style: TextStyle(
                  color: YukitasColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _SliderRow(
                key: const Key('manual-snow-depth'),
                label: '推定積雪',
                value: _snowDepthCm,
                min: 0,
                max: 100,
                divisions: 20,
                valueLabel: '${_snowDepthCm.round()} cm',
                onChanged: (value) => setState(() => _snowDepthCm = value),
              ),
              _SliderRow(
                key: const Key('manual-difficulty'),
                label: '難易度',
                value: _difficulty,
                min: 1,
                max: 5,
                divisions: 4,
                valueLabel: '${_difficulty.round()} / 5',
                onChanged: (value) => setState(() => _difficulty = value),
              ),
              _SliderRow(
                key: const Key('manual-estimated-minutes'),
                label: '推定作業時間',
                value: _estimatedMinutes,
                min: 10,
                max: 180,
                divisions: 34,
                valueLabel: '${_estimatedMinutes.round()} 分',
                onChanged:
                    (value) => setState(() => _estimatedMinutes = value),
              ),
              const SizedBox(height: 10),
              GradientActionButton(
                key: const Key('manual-analysis-confirm'),
                label: 'この内容で見積もる',
                onPressed:
                    () => Navigator.of(context).pop(
                      SnowAnalysisResult(
                        snowDepthCm: _snowDepthCm.round(),
                        areaSqm: widget.areaSqm,
                        difficulty: _difficulty.round(),
                        estimatedMinutes: _estimatedMinutes.round(),
                        confidence: 0,
                        hazards: const [],
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              valueLabel,
              style: const TextStyle(
                color: YukitasColors.action,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
