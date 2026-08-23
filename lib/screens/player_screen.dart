import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/epg.dart';
import '../services/xtream_service.dart';
import '../services/player_prefs.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // ── Pré-buffer ──────────────────────────────────────────────────────────────
  bool _isPreBuffering = true;
  double _bufferProgress = 0.0;
  String _bufferStatus = 'Conectando ao servidor...';
  Timer? _bufferFallbackTimer;
  Timer? _progressTimer;

  static const int _preBufTargetSeconds = 4;
  static const int _bufferSizeMB = 32;

  // ── Player state ─────────────────────────────────────────────────────────────
  bool _error = false;
  bool _buffering = true;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  AspectMode _aspectMode = AspectMode.wide;

  // ── OSD (programação atual) ──────────────────────────────────────────────────
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
      configuration: PlayerConfiguration(
        bufferSize: _bufferSizeMB * 1024 * 1024,
      ),
    );
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    // Buffer real → atualiza barra de progresso
    _bufferSub = _player.stream.buffer.listen(_onBufferUpdate);

    _bufferingSub = _player.stream.buffering.listen((b) {
      if (!mounted) return;
      setState(() => _buffering = b);
      // Se o player parou de bufferizar e já temos algum dado, libera pré-buffer
      if (!b && _isPreBuffering && _bufferProgress > 0.3) {
        _finishPreBuffer();
      }
    });

    _errorSub = _player.stream.error.listen((e) {
      debugPrint('Player error: $e');
      if (mounted) {
        setState(() {
          _error = true;
          _isPreBuffering = false;
        });
      }
    });

    _playingSub = _player.stream.playing.listen((playing) {
      if (playing && _isPreBuffering && _bufferProgress > 0.5) {
        _finishPreBuffer();
      }
      if (widget.autoPlay && !playing && !_error && !_buffering) {
        _player.play();
      }
    });

    _open();
    _scheduleHide();
    _maybeShowOsd();
  }

  // ── Pré-buffer helpers ───────────────────────────────────────────────────────

  void _startProgressAnimation() {
    double simulated = 0.0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      if (!_isPreBuffering) { t.cancel(); return; }
      if (simulated < 0.90) {
        simulated += 0.008;
        if (_bufferProgress < simulated) {
          setState(() {
            _bufferProgress = simulated;
            _bufferStatus = _statusFromProgress(simulated);
          });
        }
      }
    });
  }

  void _onBufferUpdate(Duration buffered) {
    if (!mounted || !_isPreBuffering) return;
    final totalSeconds = buffered.inMilliseconds / 1000.0;
    final real = (totalSeconds / _preBufTargetSeconds).clamp(0.0, 1.0);
    setState(() {
      if (real > _bufferProgress) _bufferProgress = real;
      _bufferStatus = _statusFromProgress(_bufferProgress);
    });
    if (_bufferProgress >= 1.0 || totalSeconds >= _preBufTargetSeconds) {
      _finishPreBuffer();
    }
  }

  void _finishPreBuffer() {
    if (!mounted || !_isPreBuffering) return;
    _bufferFallbackTimer?.cancel();
    _progressTimer?.cancel();
    setState(() {
      _bufferProgress = 1.0;
      _bufferStatus = 'Pronto!';
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isPreBuffering = false);
    });
  }

  String _statusFromProgress(double p) {
    if (p < 0.25) return 'Conectando ao servidor...';
    if (p < 0.50) return 'Carregando stream...';
    if (p < 0.75) return 'Preparando vídeo...';
    if (p < 0.95) return 'Quase lá...';
    return 'Pronto!';
  }

  // ── OSD ──────────────────────────────────────────────────────────────────────

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

  // ── Abertura do stream ────────────────────────────────────────────────────────

  Future<void> _openExternalPreferred(String app) async {
    Uri uri;
    switch (app) {
      case 'vlc':
        uri = Uri.parse('vlc://${widget.url}');
        break;
      case 'mx':
        uri = Uri.parse(
            'intent:${widget.url}#Intent;package=com.mxtech.videoplayer.ad;end');
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

  Future<void> _open() async {
    setState(() {
      _error = false;
      _buffering = true;
      _isPreBuffering = true;
      _bufferProgress = 0.0;
      _bufferStatus = 'Conectando ao servidor...';
    });

    // Timer fallback: libera pré-buffer após 10s mesmo que não tenha buffer suficiente
    _bufferFallbackTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isPreBuffering) {
        setState(() => _isPreBuffering = false);
      }
    });

    _startProgressAnimation();

    try {
      final pref = await PlayerPrefs.get();
      if (pref != 'internal') {
        await _openExternalPreferred(pref);
      }
      await _player.open(Media(widget.url), play: widget.autoPlay);
      await _player.setPlaylistMode(PlaylistMode.none);
      if (widget.autoPlay) await _player.play();
    } catch (e) {
      debugPrint('Open stream failed: $e');
      if (mounted) {
        setState(() {
          _error = true;
          _isPreBuffering = false;
        });
      }
    }
  }

  // ── Controles ─────────────────────────────────────────────────────────────────

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

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _hideTimer?.cancel();
    _osdTimer?.cancel();
    _bufferFallbackTimer?.cancel();
    _progressTimer?.cancel();
    _bufferingSub?.cancel();
    _bufferSub?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _isPreBuffering ? null : _toggleControls,
        child: Stack(children: [
          // Vídeo (oculto durante pré-buffer)
          AnimatedOpacity(
            opacity: _isPreBuffering ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 500),
            child: Center(
              child: _error
                  ? _ErrorView(onRetry: _open, url: widget.url)
                  : AspectRatio(
                      aspectRatio: _aspectRatio ??
                          MediaQuery.of(context).size.aspectRatio,
                      child: Video(
                        controller: _controller,
                        controls: NoVideoControls,
                        fit: _aspectMode == AspectMode.full
                            ? BoxFit.cover
                            : BoxFit.contain,
                      ),
                    ),
            ),
          ),

          // Overlay de pré-buffer
          if (_isPreBuffering) _buildPreBufferOverlay(),

          // Spinner de buffering (após pré-buffer, enquanto carrega mais dados)
          if (!_isPreBuffering && _buffering && !_error)
            const Center(child: CircularProgressIndicator(color: _kRed)),

          // OSD (programação atual)
          if (!_isPreBuffering && _showOsd) _buildOsd(),

          // Controles
          if (!_isPreBuffering && _controlsVisible) _buildControls(),
        ]),
      ),
    );
  }

  // ── Pré-buffer overlay ────────────────────────────────────────────────────────

  Widget _buildPreBufferOverlay() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              if (widget.channelLogo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.channelLogo!,
                      height: 64,
                      width: 64,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.tv, color: Colors.white54, size: 48),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Icon(Icons.tv, color: Colors.white38, size: 48),
                ),

              // Nome
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 32),

              // Barra de progresso
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _bufferStatus,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        '${(_bufferProgress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _bufferProgress,
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_kRed),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── OSD ──────────────────────────────────────────────────────────────────────

  Widget _buildOsd() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
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
                child: Image.network(
                  widget.channelLogo!,
                  width: 44,
                  height: 44,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.live_tv, color: Colors.white, size: 32),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: _kRed, borderRadius: BorderRadius.circular(3)),
                      child: const Text('AO VIVO',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  if (_currentProgram != null) ...[
                    Text(_currentProgram!.title,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: _currentProgram!.progress,
                        minHeight: 3,
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
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Controles ─────────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Stack(children: [
      // Top bar
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            GestureDetector(
              onTap: _cycleAspect,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(children: [
                  const Icon(Icons.aspect_ratio, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(_aspectLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
          ]),
        ),
      ),

      // Play/Pause central
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
                  color: Colors.white,
                  size: 36,
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final String url;
  const _ErrorView({required this.onRetry, required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: _kRed, size: 40),
        const SizedBox(height: 8),
        const Text('Erro ao carregar stream.',
            style: TextStyle(color: Colors.white)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(url,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, color: _kRed),
          label: const Text('Tentar novamente',
              style: TextStyle(color: _kRed)),
        ),
      ],
    );
  }
}
