import 'package:flutter/material.dart';
import 'player_screen.dart';

const _kRed = Color(0xFFE50914);
const _kCard = Color(0xFF161616);
const _kSurface = Color(0xFF1E1E1E);

class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  // Gera slots das últimas 24h a partir da hora atual
  late final List<_ReplaySlot> _slots;
  String _selectedDay = 'Hoje';

  @override
  void initState() {
    super.initState();
    _slots = _buildSlots();
  }

  List<_ReplaySlot> _buildSlots() {
    final now = DateTime.now();
    return List.generate(24, (i) {
      final dt = now.subtract(Duration(hours: i));
      final label =
          '${dt.hour.toString().padLeft(2, '0')}:00 — ${dt.hour.toString().padLeft(2, '0')}:59';
      final dayLabel = i < now.hour ? 'Hoje' : 'Ontem';
      // Substitua pelo padrão de URL real do seu servidor
      final url =
          'https://servertv.dreamserver.shop/replay/${dt.year}${dt.month.toString().padLeft(2,'0')}${dt.day.toString().padLeft(2,'0')}/${dt.hour.toString().padLeft(2,'0')}.m3u8';
      return _ReplaySlot(label: label, url: url, day: dayLabel, hour: dt.hour);
    });
  }

  List<_ReplaySlot> get _filtered =>
      _slots.where((s) => s.day == _selectedDay).toList();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(children: [
              Container(width: 3, height: 18,
                  decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('Replay',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Assista o que passou nas últimas 24h',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),

          // Day filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: ['Hoje', 'Ontem'].map((day) {
              final sel = day == _selectedDay;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = day),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? _kRed : _kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: sel ? null : Border.all(color: Colors.white12),
                  ),
                  child: Text(day,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.grey,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 12),

          // Lista de slots
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final slot = _filtered[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: _kRed.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.replay_rounded, color: _kRed, size: 22),
                    ),
                    title: Text(slot.label,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(slot.day,
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    trailing: const Icon(Icons.play_circle_outline_rounded, color: _kRed, size: 26),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                          title: 'Replay ${slot.label}',
                          url: slot.url,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplaySlot {
  final String label;
  final String url;
  final String day;
  final int hour;
  const _ReplaySlot({required this.label, required this.url, required this.day, required this.hour});
}