import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/epg.dart';
import '../services/xtream_service.dart';

const _kRed = Color(0xFFE50914);

enum AspectMode { wide, fit, full }

class PlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  final String? channelLogo;
  final String? channelId;
  final XtreamService? service;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.url,
    this.channelLogo,
    this.channelId,
    this.service,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription? _errorSub;
  StreamSubscription? _bufferingSub;

  bool _error = false;
  bool _buffering = true;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  AspectMode _aspectMode = AspectMode.wide;

  bool _showOsd = false;
  EpgProgram? _currentProgram;
  Timer? _osdTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 16 * 1024 * 1024,
      ),
    );
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _bufferingSub = _player.stream.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    });
    _errorSub = _player.stream.error.listen((e) {
      if (mounted) setState(() => _error = true);
    });

    _open();
    _scheduleHide();
    _maybeShowOsd();
  }

  void _maybeShowOsd() async {
    if (widget.channelId == null || widget.service == null) return;
    setState(() => _showOsd = true);
    widget.service!.getCurrentProgram(widget.channelId!).then((p) {
      if (mounted && _showOsd) setState(() => _currentProgram = p);
    });
    _osdTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) setState(() => _showOsd = false);
    });
  }

  Future<void> _open() async {
    setState(() { _error = false; _buffering = true; });
    try {
      await _player.open(Media(widget.url));
      await _player.setPlaylistMode(PlaylistMode.none);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _cycleAspect() {
    setState(() {
      _aspectMode = switch (_aspectMode) {
        AspectMode.wide => AspectMode.fit,
        AspectMode.fit  => AspectMode.full,
        AspectMode.full => AspectMode.wide,
      };
    });
    _scheduleHide();
  }

  double? get _aspectRatio {
    switch (_aspectMode) {
      case AspectMode.wide: return 16 / 9;
      case AspectMode.fit:  return 4 / 3;
      case AspectMode.full: return null;
    }
  }

  String get _aspectLabel {
    switch (_aspectMode) {
      case AspectMode.wide: return '16:9';
      case AspectMode.fit:  return '4:3';
      case AspectMode.full: return 'Preencher';
    }
  }

  // ── Player externo ──────────────────────────────────────
  void _openExternal(String app) async {
    // Pausa o player interno antes de abrir o externo
    await _player.pause();

    Uri uri;
    switch (app) {
      case 'vlc':
        uri = Uri.parse('vlc://${widget.url}');
        break;
      case 'mx':
        uri = Uri.parse(
          'intent:${widget.url}#Intent;package=com.mxtech.videoplayer.ad;end',
        );
        break;
      default:
        uri = Uri.parse(widget.url);
    }

    final ok = await canLaunchUrl(uri);
    if (ok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            app == 'vlc'
                ? 'VLC não encontrado. Instale o VLC para Android.'
                : app == 'mx'
                    ? 'MX Player não encontrado.'
                    : 'Nenhum player externo disponível.',
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Retoma o player interno se o externo não abriu
      await _player.play();
    }
  }

  void _showExternalMenu() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Abrir em player externo',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            _ExternalOption(
              icon: Icons.play_circle_fill_rounded,
              label: 'VLC Media Player',
              subtitle: 'com.videolan.vlc',
              onTap: () { Navigator.pop(context); _openExternal('vlc'); },
            ),
            _ExternalOption(
              icon: Icons.smart_display_rounded,
              label: 'MX Player',
              subtitle: 'com.mxtech.videoplayer.ad',
              onTap: () { Navigator.pop(context); _openExternal('mx'); },
            ),
            _ExternalOption(
              icon: Icons.open_in_new_rounded,
              label: 'Outro player',
              subtitle: 'Abre com o app padrão do sistema',
              onTap: () { Navigator.pop(context); _openExternal('other'); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).whenComplete(_scheduleHide);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _hideTimer?.cancel();
    _osdTimer?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(children: [
          // Vídeo
          Center(
            child: _error
                ? _ErrorView(onRetry: _open)
                : AspectRatio(
                    aspectRatio: _aspectRatio ?? MediaQuery.of(context).size.aspectRatio,
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      fit: _aspectMode == AspectMode.full ? BoxFit.cover : BoxFit.contain,
                    ),
                  ),
          ),

          // Buffering
          if (_buffering && !_error)
            const Center(child: CircularProgressIndicator(color: _kRed)),

          // OSD — aviso de canal por 7s
          if (_showOsd)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: GestureDetector(
                onTap: () => setState(() => _showOsd = false),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(children: [
                    if (widget.channelLogo != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Image.network(widget.channelLogo!, width: 44, height: 44,
                            errorBuilder: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.white, size: 32)),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(3)),
                              child: const Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(widget.title,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          if (_currentProgram != null) ...[
                            Text(_currentProgram!.title,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: _currentProgram!.progress, minHeight: 3,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(_kRed),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(_currentProgram!.timeRange, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          ] else
                            const Text('Carregando programação...', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),

          // Controles — topo
          if (_controlsVisible)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),

                  // Botão aspect ratio
                  GestureDetector(
                    onTap: _cycleAspect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(children: [
                        const Icon(Icons.aspect_ratio, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(_aspectLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ]),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Botão player externo ← NOVO
                  GestureDetector(
                    onTap: _showExternalMenu,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(children: [
                        Icon(Icons.open_in_new_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Externo', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ]),
                    ),
                  ),

                  const SizedBox(width: 8),
                ]),
              ),
            ),

          // Play/Pause central
          if (_controlsVisible && !_error)
            Center(
              child: StreamBuilder<bool>(
                stream: _player.stream.playing,
                initialData: true,
                builder: (context, snap) {
                  final playing = snap.data ?? true;
                  return GestureDetector(
                    onTap: () {
                      playing ? _player.pause() : _player.play();
                      _scheduleHide();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white, size: 36,
                      ),
                    ),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Widget de opção no bottom sheet ─────────────────────
class _ExternalOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ExternalOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: _kRed.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: _kRed, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      onTap: onTap,
    );
  }
}

// ── Tela de erro ─────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: _kRed, size: 40),
        const SizedBox(height: 8),
        const Text('Erro ao carregar stream.', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, color: _kRed),
          label: const Text('Tentar novamente', style: TextStyle(color: _kRed)),
        ),
      ],
    );
  }
}