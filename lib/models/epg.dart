import 'dart:convert';
import 'channel.dart';

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

    // O Xtream Codes retorna title/description em Base64.
    String decodeMaybeBase64(dynamic val) {
      if (val == null) return '';
      final s = val.toString();
      if (s.isEmpty) return s;
      try {
        return utf8.decode(base64.decode(s));
      } catch (_) {
        // Já vem como texto puro em alguns painéis — usa como está.
        return s;
      }
    }

    final rawTitle = j['title'] ?? j['name'];
    final rawDesc = j['description'] ?? j['plot'];

    return EpgProgram(
      title: rawTitle != null && rawTitle.toString().isNotEmpty
          ? decodeMaybeBase64(rawTitle)
          : 'Sem título',
      channelId: j['channel_id']?.toString() ?? j['stream_id']?.toString() ?? '',
      start: parseTime(j['start_timestamp'] ?? j['start']),
      end: parseTime(j['stop_timestamp'] ?? j['end'] ?? j['stop']),
      description: rawDesc != null ? decodeMaybeBase64(rawDesc) : null,
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

/// Agrupa um canal com sua programação (usado na grade do EPG).
class EpgChannel {
  final Channel channel;
  final List<EpgProgram> programs;

  EpgChannel({required this.channel, required this.programs});

  EpgProgram? get currentProgram {
    final now = DateTime.now();
    for (final p in programs) {
      if (now.isAfter(p.start) && now.isBefore(p.end)) return p;
    }
    return null;
  }
}