/// Formats [timestamp] as a short relative string such as "2 weeks ago".
///
/// Returns "Unknown" for a null timestamp. [now] is injectable for tests.
String formatRelativeTime(DateTime? timestamp, {DateTime? now}) {
  if (timestamp == null) {
    return 'Unknown';
  }

  final reference = (now ?? DateTime.now()).toUtc();
  final difference = reference.difference(timestamp.toUtc());

  // Clock skew can put a server timestamp slightly in the future.
  if (difference.inMinutes < 1) {
    return 'Just now';
  }
  if (difference.inMinutes < 60) {
    return _plural(difference.inMinutes, 'minute');
  }
  if (difference.inHours < 24) {
    return _plural(difference.inHours, 'hour');
  }
  if (difference.inDays < 7) {
    return difference.inDays == 1 ? 'Yesterday' : _plural(difference.inDays, 'day');
  }
  if (difference.inDays < 30) {
    return _plural(difference.inDays ~/ 7, 'week');
  }
  if (difference.inDays < 365) {
    return _plural(difference.inDays ~/ 30, 'month');
  }
  return _plural(difference.inDays ~/ 365, 'year');
}

String _plural(int count, String unit) => '$count $unit${count == 1 ? '' : 's'} ago';
