class EpgProgram {
  final String title;
  final String channelId;
  final DateTime start;
  final DateTime end;
  final String? description;

  EpgProgram({
    required this.title,
    required this.channelId,
    required this.start,
    required this.end,
    this.description,
  });

  factory EpgProgram.fromJson(Map<String, dynamic> j) {
    DateTime parseTime(dynamic val) {
      try {
        if (val == null) return DateTime.now();
        final s = val.toString();
        // Xtream retorna timestamp unix ou string de data
        final ts = int.tryParse(s);
        if (ts != null) return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.now();
      }
    }

    return EpgProgram(
      title: j['title'] ?? j['name'] ?? 'Sem título',
      channelId: j['channel_id']?.toString() ?? j['stream_id']?.toString() ?? '',
      start: parseTime(j['start_timestamp'] ?? j['start']),
      end: parseTime(j['stop_timestamp'] ?? j['end'] ?? j['stop']),
      description: j['description'] ?? j['plot'],
    );
  }

  bool get isLive => DateTime.now().isAfter(start) && DateTime.now().isBefore(end);

  double get progress {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String get timeRange {
    String fmt(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${fmt(start)} - ${fmt(end)}';
  }
}
