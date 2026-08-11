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