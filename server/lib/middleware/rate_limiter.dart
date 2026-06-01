class RateLimiter {
  RateLimiter({required this.maxRequests, required this.window});

  final int maxRequests;
  final Duration window;
  final Map<String, List<DateTime>> _eventsByKey = {};

  bool allow(String key) {
    final now = DateTime.now().toUtc();
    final bucket = _eventsByKey.putIfAbsent(key, () => <DateTime>[]);

    bucket.removeWhere((eventTime) => now.difference(eventTime) >= window);

    if (bucket.length >= maxRequests) {
      return false;
    }

    bucket.add(now);
    return true;
  }
}
