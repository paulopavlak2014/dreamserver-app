import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import '../models/epg.dart';
import 'player_screen.dart';

class EpgScreen extends StatefulWidget {
  final XtreamService service;
  const EpgScreen({super.key, required this.service});

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  List<Channel> _channels = [];
  List<EpgChannel> _epgData = [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();
  List<EpgChannel> _filtered = [];

  // Grade: pixels por minuto
  static const double _pxPerMin = 4.0;
  static const double _rowHeight = 72.0;
  static const double _labelWidth = 120.0;
  static const double _timeHeaderHeight = 32.0;

  // Janela de tempo visível: 3 horas antes até 3 horas depois
  late DateTime _windowStart;
  late DateTime _windowEnd;
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _initWindow();
    _load();
    _search.addListener(_applyFilter);
  }

  void _initWindow() {
    final now = DateTime.now();
    _windowStart = now.subtract(const Duration(hours: 2));
    _windowEnd = now.add(const Duration(hours: 6));
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _epgData
          : _epgData
              .where((e) => e.channel.name.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final channels = await widget.service.getLiveChannels();
      // Carrega EPG dos primeiros 50 canais para não sobrecarregar
      final top = channels.take(80).toList();
      final epg = await widget.service.getEpg(channels: top, limit: 6);

      // Para canais sem EPG, cria entrada vazia
      final epgIds = epg.map((e) => e.channel.id).toSet();
      final empties = top
          .where((c) => !epgIds.contains(c.id))
          .map((c) => EpgChannel(channel: c, programs: []));

      final all = [...epg, ...empties];
      all.sort((a, b) => a.channel.name.compareTo(b.channel.name));

      setState(() {
        _channels = channels;
        _epgData = all;
        _filtered = all;
        _loading = false;
      });

      // Scroll para o horário atual
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _scrollToNow() {
    final now = DateTime.now();
    final offset = now.difference(_windowStart).inMinutes * _pxPerMin - 100;
    if (_hScroll.hasClients) {
      _hScroll.animateTo(
        offset.clamp(0, _hScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    }
  }

  double _timeToX(DateTime t) {
    return t.difference(_windowStart).inMinutes * _pxPerMin;
  }

  double get _totalWidth => _windowEnd.difference(_windowStart).inMinutes * _pxPerMin;

  @override
  void dispose() {
    _search.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 50),
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Text('EPG', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _search,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Filtrar canal...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.access_time, color: Color(0xFFE50914)),
            tooltip: 'Ir para agora',
            onPressed: _scrollToNow,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            tooltip: 'Recarregar',
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFE50914)),
            SizedBox(height: 16),
            Text('Carregando grade de programação...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE50914), size: 48),
            const SizedBox(height: 12),
            Text('Erro ao carregar EPG', style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            TextButton.icon(icon: const Icon(Icons.refresh), label: const Text('Tentar novamente'), onPressed: _load),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(child: Text('Nenhum canal encontrado', style: TextStyle(color: Colors.grey)));
    }

    return Column(
      children: [
        // Cabeçalho de horários (fixo no topo, scroll horizontal)
        SizedBox(
          height: _timeHeaderHeight,
          child: Row(
            children: [
              SizedBox(width: _labelWidth), // espaço para labels de canal
              Expanded(
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildTimeHeader(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        // Grade principal
        Expanded(
          child: SingleChildScrollView(
            controller: _vScroll,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna de nomes de canais (fixa à esquerda)
                SizedBox(
                  width: _labelWidth,
                  child: Column(
                    children: _filtered.map((ec) => _buildChannelLabel(ec)).toList(),
                  ),
                ),
                // Grade de programas (scroll horizontal)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _totalWidth,
                      child: Stack(
                        children: [
                          // Linhas de programas
                          Column(
                            children: _filtered.map((ec) => _buildChannelRow(ec)).toList(),
                          ),
                          // Linha "agora"
                          _buildNowLine(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeHeader() {
    final slots = <Widget>[];
    var t = DateTime(
      _windowStart.year,
      _windowStart.month,
      _windowStart.day,
      _windowStart.hour,
    );
    if (t.isBefore(_windowStart)) t = t.add(const Duration(hours: 1));

    while (t.isBefore(_windowEnd)) {
      final x = _timeToX(t);
      slots.add(Positioned(
        left: x,
        child: SizedBox(
          width: 60 * _pxPerMin,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '${t.hour.toString().padLeft(2, '0')}:00',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ),
      ));
      t = t.add(const Duration(hours: 1));
    }

    return SizedBox(
      width: _totalWidth,
      height: _timeHeaderHeight,
      child: Stack(children: slots),
    );
  }

  Widget _buildChannelLabel(EpgChannel ec) {
    final now = ec.currentProgram;
    return Container(
      height: _rowHeight,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
      ),
      child: InkWell(
        onTap: () => _playChannel(ec.channel),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: ec.channel.logo != null
                    ? CachedNetworkImage(
                        imageUrl: ec.channel.logo!,
                        width: 36, height: 24,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.grey, size: 20),
                      )
                    : const Icon(Icons.live_tv, color: Colors.grey, size: 20),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ec.channel.name,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelRow(EpgChannel ec) {
    final programs = ec.programs
        .where((p) => p.end.isAfter(_windowStart) && p.start.isBefore(_windowEnd))
        .toList();

    return Container(
      height: _rowHeight,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
      ),
      child: Stack(
        children: [
          if (programs.isEmpty)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: const Text('Sem informação', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ),
            ),
          ...programs.map((p) => _buildProgramBlock(p, ec.channel)),
        ],
      ),
    );
  }

  Widget _buildProgramBlock(EpgProgram p, Channel channel) {
    final startX = _timeToX(p.start.isBefore(_windowStart) ? _windowStart : p.start);
    final endX = _timeToX(p.end.isAfter(_windowEnd) ? _windowEnd : p.end);
    final width = (endX - startX).clamp(2.0, double.infinity);
    final isLive = p.isLive;

    return Positioned(
      left: startX,
      top: 2,
      bottom: 2,
      width: width,
      child: GestureDetector(
        onTap: () => _showProgramDetail(p, channel),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isLive ? const Color(0xFF1A0A0A) : const Color(0xFF181818),
            border: Border.all(
              color: isLive ? const Color(0xFFE50914) : const Color(0xFF2A2A2A),
              width: isLive ? 1.5 : 0.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // Barra de progresso
              if (isLive)
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  width: width * p.progress,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              // Conteúdo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (isLive) ...[
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE50914),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            p.title,
                            style: TextStyle(
                              color: isLive ? Colors.white : const Color(0xFFBBBBBB),
                              fontSize: 11,
                              fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (width > 80) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.timeRange,
                        style: const TextStyle(color: Colors.grey, fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNowLine() {
    final now = DateTime.now();
    if (now.isBefore(_windowStart) || now.isAfter(_windowEnd)) return const SizedBox();
    final x = _timeToX(now);
    return Positioned(
      left: x,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: 2,
          color: const Color(0xFFE50914).withOpacity(0.8),
        ),
      ),
    );
  }

  void _playChannel(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(title: channel.name, url: channel.streamUrl),
      ),
    );
  }

  void _showProgramDetail(EpgProgram p, Channel channel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (p.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                Expanded(
                  child: Text(
                    channel.name,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(p.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(p.timeRange, style: const TextStyle(color: Color(0xFFE50914), fontSize: 13)),
            if (p.description != null && p.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(p.description!, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13, height: 1.5)),
            ],
            if (p.isLive) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Assistir agora', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(context);
                    _playChannel(channel);
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}