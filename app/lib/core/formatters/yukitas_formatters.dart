String formatYen(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '$buffer円';
}

String formatArea(double value) {
  final rounded =
      value.roundToDouble() == value
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
  return '$rounded m²';
}

/// Distance from a worker to a request, always hedged with 約.
///
/// It is measured to the request's published cell center rather than the
/// address itself, so presenting it as an exact figure would be a lie - the
/// real distance is within roughly a kilometre of this.
String formatApproxDistance(double kilometres) {
  if (kilometres < 1) return '約${(kilometres * 1000).round()}m';
  return '約${kilometres.toStringAsFixed(1)}km';
}

String formatDate(DateTime value) => '${value.month}月${value.day}日';

String formatDateTime(DateTime value) =>
    '${formatDate(value)} ${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';

/// Short "how long ago" label for history lists. Falls back to an absolute
/// date once an entry is older than a week, where the exact day matters more
/// than the elapsed time.
String formatRelativeDate(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final difference = reference.difference(value);
  if (difference.isNegative) return formatDate(value);
  if (difference.inMinutes < 1) return 'たった今';
  if (difference.inMinutes < 60) return '${difference.inMinutes}分前';
  if (difference.inHours < 24) return '${difference.inHours}時間前';
  if (difference.inDays < 7) return '${difference.inDays}日前';
  return formatDate(value);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
