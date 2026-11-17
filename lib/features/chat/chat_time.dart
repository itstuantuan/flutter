/// Group nearby messages; a new day always starts a new timestamp section.
bool showChatTime(DateTime? previous, DateTime? current) {
  if (current == null) return false;
  if (previous == null) return true;
  final a = previous.toLocal(), b = current.toLocal();
  return a.year != b.year ||
      a.month != b.month ||
      a.day != b.day ||
      b.difference(a) >= const Duration(minutes: 5);
}

String formatChatTime(DateTime value, {DateTime? now}) {
  final time = value.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final date = DateTime(time.year, time.month, time.day);
  final todayDate = DateTime(today.year, today.month, today.day);
  final clock =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  if (date == todayDate) return clock;
  if (date == DateTime(today.year, today.month, today.day - 1)) {
    return '昨天 $clock';
  }
  if (time.year == today.year) return '${time.month}月${time.day}日 $clock';
  return '${time.year}年${time.month}月${time.day}日 $clock';
}
