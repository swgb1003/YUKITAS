import 'package:flutter/material.dart';

/// Shared by the requester and worker "問題を報告" flows (spec 09章:
/// "matched以降 → cancelled / disputed 当事者 理由必須").
Future<String?> promptForReportReason(BuildContext context) {
  return _promptForReason(
    context,
    title: '問題を報告',
    hintText: '状況を入力してください（必須）',
    submitLabel: '報告する',
  );
}

/// Used when the requester cancels a still-unmatched request (spec 09章:
/// "waiting → cancelled 依頼者 未受注。キャンセル理由を記録。").
Future<String?> promptForCancelReason(BuildContext context) {
  return _promptForReason(
    context,
    title: '依頼をキャンセル',
    hintText: 'キャンセルの理由を入力してください（必須）',
    submitLabel: 'キャンセルする',
  );
}

/// Shows a dialog collecting a required reason and returns the trimmed text,
/// or null if the user dismissed it.
Future<String?> _promptForReason(
  BuildContext context, {
  required String title,
  required String hintText,
  required String submitLabel,
}) {
  return showDialog<String>(
    context: context,
    builder:
        (dialogContext) => _ReasonDialog(
          title: title,
          hintText: hintText,
          submitLabel: submitLabel,
        ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hintText,
    required this.submitLabel,
  });

  final String title;
  final String hintText;
  final String submitLabel;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('reason-dialog-field'),
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        FilledButton(
          key: const Key('reason-dialog-submit'),
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.isEmpty) return;
            Navigator.of(context).pop(reason);
          },
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
