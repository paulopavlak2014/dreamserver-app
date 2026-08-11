class Channel {
  final String id;
  final String name;
  final String streamUrl;
  final String? logo;
  final String? category;

  Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logo,
    this.category,
  });

  factory Channel.fromJson(Map<String, dynamic> j, String baseUrl, String user, String pass) {
    final sid = j['stream_id']?.toString() ?? '';
    return Channel(
      id: sid,
      name: j['name'] ?? '',
      streamUrl: '$baseUrl/live/$user/$pass/$sid.ts',
      logo: j['stream_icon'],
      category: j['category_id']?.toString(),
    );
  }
}

class Movie {
  final String id;
  final String name;
  final String streamUrl;
  final String? cover;
  final String? plot;
  final String? genre;
  final String? rating;
  final String? year;

  Movie({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.cover,
    this.plot,
    this.genre,
    this.rating,
    this.year,
  });

  factory Movie.fromJson(Map<String, dynamic> j, String baseUrl, String user, String pass) {
    final sid = j['stream_id']?.toString() ?? '';
    final ext = j['container_extension'] ?? 'mp4';
    return Movie(
      id: sid,
      name: j['name'] ?? '',
      streamUrl: '$baseUrl/movie/$user/$pass/$sid.$ext',
      cover: j['stream_icon'] ?? j['cover'],
      plot: j['plot'],
      genre: j['genre'],
      rating: j['rating']?.toString(),
      year: j['year']?.toString(),
    );
  }
}

class Series {
  final String id;
  final String name;
  final String? cover;
  final String? plot;
  final String? genre;
  final String? rating;
  final String? year;

  Series({
    required this.id,
    required this.name,
    this.cover,
    this.plot,
    this.genre,
    this.rating,
    this.year,
  });

  factory Series.fromJson(Map<String, dynamic> j) {
    return Series(
      id: j['series_id']?.toString() ?? '',
      name: j['name'] ?? '',
      cover: j['cover'],
      plot: j['plot'],
      genre: j['genre'],
      rating: j['rating']?.toString(),
      year: j['year']?.toString(),
    );
  }
}

// ── EPG ─────────────────────────────────────────────────────────────────────

class EpgProgram {
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String channelId;

  EpgProgram({
    required this.title,
    this.description,
    required this.start,
    required this.end,
    required this.channelId,
  });

  Duration get duration => end.difference(start);

  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  double get progress {
    final now = DateTime.now();
    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end)) return 1.0;
    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    return elapsed / total;
  }

  String get timeRange {
    String fmt(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${fmt(start)} – ${fmt(end)}';
  }
}

class EpgChannel {
  final Channel channel;
  final List<EpgProgram> programs;

  EpgChannel({required this.channel, required this.programs});

  EpgProgram? get currentProgram {
    final now = DateTime.now();
    try {
      return programs.firstWhere((p) => now.isAfter(p.start) && now.isBefore(p.end));
    } catch (_) {
      return null;
    }
  }

  EpgProgram? get nextProgram {
    final now = DateTime.now();
    final upcoming = programs.where((p) => p.start.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.isEmpty ? null : upcoming.first;
  }
}
