import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/epg.dart';
import '../services/xtream_service.dart';
import '../services/player_prefs.dart';

const _kRed = Color(0xFFE50914);

enum AspectMode { wide, fit, full }

class PlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  final String? channelLogo;
  final String? channelId;
  final XtreamService? service;
  final bool autoPlay;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.url,
    this.channelLogo,
    this.channelId,
    this.service,
    this.autoPlay = true,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription? _errorSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _bufferSub;

  bool _error = false;
  bool _buffering = true;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  Timer? _retryTimer;
  AspectMode _aspectMode = AspectMode.wide;

  bool _showOsd = false;
  EpgProgram? _currentProgram;
  Timer? _osdTimer;

  // Pré-buffer
  static const _kPreBufferSec = 3.0;
  bool _preBuffering = true;
  double _bufferProgress = 0;
  Duration _bufferPos = Duration.zero;

  // Reconexão automática
  int _retryCount = 0;
  static const _kMaxRetries = 5;
  bool _retrying = false;
  String _retryMsg = '';

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
        bufferSize: 64 * 1024 * 1024,
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
      debugPrint('Player error: $e');
      if (mounted) _handleError();
    });

    _playingSub = _player.stream.playing.listen((playing) {
      if (widget.autoPlay && !playing && !_error && !_buffering) {
        _player.play();
      }
    });

    _bufferSub = _player.stream.buffer.listen((buf) {
      if (!mounted || !_preBuffering) return;
      final secs = buf.inMilliseconds / 1000.0;
      final progress = (secs / _kPreBufferSec).clamp(0.0, 1.0);
      setState(() {
        _bufferPos = buf;
        _bufferProgress = progress;
      });
      if (secs >= _kPreBufferSec) {
        setState(() => _preBuffering = false);
      }
    });

    _open();
    _scheduleHide();
    _maybeShowOsd();
  }

  // ── Reconexão automática ────────────────────────────────
  void _handleError() {
    if (_retryCount >= _kMaxRetries) {
      setState(() { _error = true; _retrying = false; _preBuffering = false; });
      return;
    }
    _retryCount++;
    final delay = _retryCount * 3; // 3s, 6s, 9s, 12s, 15s
    setState(() {
      _retrying = true;
      _error = false;
      _preBuffering = false;
      _retryMsg = 'Stream interrompido. Reconectando em ${delay}s... (tentativa $_retryCount/$_kMaxRetries)';
    });
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delay), () {
      if (mounted) _open(isRetry: true);
    });
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

  Future<void> _openExternalPreferred(String app) async {
    Uri uri;
    switch (app) {
      case 'vlc':
        uri = Uri.parse('vlc://${widget.url}');
        break;
      case 'mx':
        uri = Uri.parse('intent:${widget.url}#Intent;package=com.mxtech.videoplayer.ad;end');
        break;
      default:
        uri = Uri.parse(widget.url);
    }
    final ok = await canLaunchUrl(uri);
    if (ok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _open({bool isRetry = false}) async {
    setState(() {
      _error = false;
      _buffering = true;
      if (!isRetry) {
        _preBuffering = true;
        _bufferProgress = 0;
        _retryCount = 0;
      }
      _retrying = false;
    });
    try {
      final pref = await PlayerPrefs.get();
      if (pref != 'internal' && !isRetry) {
        await _openExternalPreferred(pref);
      }
      await _player.open(Media(widget.url), play: widget.autoPlay);
      await _player.setPlaylistMode(PlaylistMode.none);
      if (widget.autoPlay) await _player.play();
    } catch (e) {
      debugPrint('Open stream failed: $e');
      if (mounted) _handleError();
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

  double? get _aspectRatio => switch (_aspectMode) {
    AspectMode.wide => 16 / 9,
    AspectMode.fit  => 4 / 3,
    AspectMode.full => null,
  };

  String get _aspectLabel => switch (_aspectMode) {
    AspectMode.wide => '16:9',
    AspectMode.fit  => '4:3',
    AspectMode.full => 'Preencher',
  };

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _hideTimer?.cancel();
    _osdTimer?.cancel();
    _retryTimer?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _bufferSub?.cancel();
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
          Positioned.fill(
            child: (_error || _retrying)
                ? const SizedBox.shrink()
                : Opacity(
                    opacity: _preBuffering ? 0.0 : 1.0,
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      fit: _aspectMode == AspectMode.full ? BoxFit.cover : BoxFit.contain,
                    ),
                  ),
          ),

          // Erro final
          if (_error)
            Center(child: _ErrorView(onRetry: () { _retryCount = 0; _open(); }, url: widget.url)),

          // Reconectando
          if (_retrying)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: _kRed),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(_retryMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () { _retryTimer?.cancel(); _retryCount = 0; _open(); },
                  child: const Text('Reconectar agora', style: TextStyle(color: _kRed)),
                ),
              ]),
            ),

          // Pré-buffer
          if (_preBuffering && !_error && !_retrying)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.channelLogo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Image.network(widget.channelLogo!, width: 64, height: 64,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.live_tv, color: Colors.white54, size: 48)),
                  ),
                Text(widget.title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 20),
                SizedBox(
                  width: 220,
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Preparando stream...',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text('${(_bufferProgress * 100).toInt()}%',
                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _bufferProgress, minHeight: 5,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(_kRed),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Buffer: ${_bufferPos.inSeconds}s / ${_kPreBufferSec.toInt()}s',
                        style: const TextStyle(color: Colors.white24, fontSize: 10)),
                  ]),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _preBuffering = false),
                  child: const Text('Pular e assistir agora',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ]),
            ),

          // Buffering após pré-buffer
          if (_buffering && !_preBuffering && !_error && !_retrying)
            const Center(child: CircularProgressIndicator(color: _kRed)),

          // OSD
          if (_showOsd && !_preBuffering && !_retrying)
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
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.live_tv, color: Colors.white, size: 32)),
                      ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(3)),
                            child: const Text('AO VIVO',
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(widget.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                          Text(_currentProgram!.timeRange,
                              style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ] else
                          const Text('Carregando programação...',
                              style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

          // Controles topo
          if (_controlsVisible && !_preBuffering && !_retrying)
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
                  Expanded(child: Text(widget.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  _TvButton(
                    onTap: _cycleAspect,
                    child: Row(children: [
                      const Icon(Icons.aspect_ratio, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(_aspectLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                ]),
              ),
            ),

          // Play/Pause central
          if (_controlsVisible && !_error && !_preBuffering && !_retrying)
            Center(
              child: StreamBuilder<bool>(
                stream: _player.stream.playing,
                initialData: true,
                builder: (_, snap) {
                  final playing = snap.data ?? true;
                  return _TvButton(
                    onTap: () {
                      playing ? _player.pause() : _player.play();
                      _scheduleHide();
                    },
                    padding: const EdgeInsets.all(14),
                    borderRadius: 50,
                    child: Icon(playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white, size: 36),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Botão com foco visível para TV/Firestick ─────────────
class _TvButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsets padding;
  final double borderRadius;

  const _TvButton({
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.borderRadius = 6,
  });

  @override
  State<_TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<_TvButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) { widget.onTap(); return null; }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _focused ? _kRed.withOpacity(0.8) : Colors.white12,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _focused ? _kRed : Colors.white24,
              width: _focused ? 2 : 1,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final String url;
  const _ErrorView({required this.onRetry, required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.signal_wifi_off_rounded, color: _kRed, size: 48),
      const SizedBox(height: 12),
      const Text('Não foi possível carregar o stream',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('Verifique sua conexão ou tente novamente.',
          style: TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Tentar novamente'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kRed, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);
  }
}
