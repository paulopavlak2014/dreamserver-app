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
      name: j['name']?.toString() ?? '',
      streamUrl: '$baseUrl/live/$user/$pass/$sid.ts',
      logo: j['stream_icon']?.toString(),
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
  final String? categoryId;

  Movie({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.cover,
    this.plot,
    this.genre,
    this.rating,
    this.year,
    this.categoryId,
  });

  factory Movie.fromJson(Map<String, dynamic> j, String baseUrl, String user, String pass) {
    final sid = j['stream_id']?.toString() ?? '';
    final ext = (j['container_extension'] ?? 'mp4').toString();
    return Movie(
      id: sid,
      name: j['name']?.toString() ?? '',
      streamUrl: '$baseUrl/movie/$user/$pass/$sid.$ext',
      cover: (j['stream_icon'] ?? j['cover'])?.toString(),
      plot: j['plot']?.toString(),
      genre: j['genre']?.toString(),
      rating: j['rating']?.toString(),
      year: j['year']?.toString(),
      categoryId: j['category_id']?.toString(),
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
  final String? categoryId;

  Series({
    required this.id,
    required this.name,
    this.cover,
    this.plot,
    this.genre,
    this.rating,
    this.year,
    this.categoryId,
  });

  factory Series.fromJson(Map<String, dynamic> j) {
    return Series(
      id: (j['series_id'] ?? j['stream_id'] ?? '').toString(),
      name: (j['name'] ?? j['title'] ?? '').toString(),
      cover: (j['cover'] ?? j['stream_icon'] ?? j['poster'])?.toString(),
      plot: j['plot']?.toString(),
      genre: j['genre']?.toString(),
      rating: j['rating']?.toString(),
      year: j['year']?.toString(),
      categoryId: j['category_id']?.toString(),
    );
  }
}

class Category {
  final String id;
  final String name;
  Category({required this.id, required this.name});
  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['category_id']?.toString() ?? '',
        name: j['category_name']?.toString() ?? 'Categoria',
      );
}
