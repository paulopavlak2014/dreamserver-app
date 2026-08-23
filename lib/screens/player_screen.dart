import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? logo;

  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.logo,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  // Pré-buffer state
  bool _isPreBuffering = true;
  double _bufferProgress = 0.0;
  String _bufferStatus = 'Preparando stream...';
  Timer? _bufferTimer;
  Timer? _progressTimer;

  // Configurações de buffer
  static const int _preBufTargetSeconds = 4; // segundos antes de exibir
  static const int _bufferSizeMB = 32;        // 32MB buffer total

  // UI state
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _initPlayer() async {
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: _bufferSizeMB * 1024 * 1024,
        logLevel: MPVLogLevel.error,
      ),
    );

    _controller = VideoController(_player);

    // Listener de buffer
    _player.stream.buffer.listen(_onBufferUpdate);
    _player.stream.buffering.listen(_onBufferingChange);
    _player.stream.playing.listen(_onPlayingChange);
    _player.stream.error.listen(_onError);

    await _player.open(Media(widget.url), play: true);

    // Timer de fallback: se após 10s ainda não saiu do pré-buffer, libera mesmo assim
    _bufferTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isPreBuffering) {
        setState(() {
          _isPreBuffering = false;
          _bufferProgress = 1.0;
        });
      }
    });

    // Simula progresso visual suave enquanto buferiza
    _startProgressAnimation();
  }

  void _startProgressAnimation() {
    double simulated = 0.0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      if (!_isPreBuffering) { t.cancel(); return; }

      // Avança até 90% simulado — o resto vem do buffer real
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

  void _onBufferingChange(bool buffering) {
    // Se o player já saiu do buffering e temos dados, libera o pré-buffer
    if (!buffering && _isPreBuffering && _bufferProgress > 0.3) {
      _finishPreBuffer();
    }
  }

  void _onPlayingChange(bool playing) {
    if (playing && _isPreBuffering && _bufferProgress > 0.5) {
      _finishPreBuffer();
    }
  }

  void _onError(String error) {
    if (!mounted) return;
    setState(() {
      _isPreBuffering = false;
      _bufferStatus = 'Erro ao carregar stream';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro: $error'),
        backgroundColor: Colors.red.shade800,
        action: SnackBarAction(
          label: 'Tentar novamente',
          onPressed: _retry,
        ),
      ),
    );
  }

  void _finishPreBuffer() {
    if (!mounted || !_isPreBuffering) return;
    _bufferTimer?.cancel();
    _progressTimer?.cancel();
    setState(() {
      _bufferProgress = 1.0;
      _bufferStatus = 'Pronto!';
    });
    // Pequeno delay visual para mostrar "Pronto!" antes de sumir
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

  Future<void> _retry() async {
    setState(() {
      _isPreBuffering = true;
      _bufferProgress = 0.0;
      _bufferStatus = 'Reconectando...';
    });
    await _player.open(Media(widget.url), play: true);
    _startProgressAnimation();
    _bufferTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isPreBuffering) setState(() => _isPreBuffering = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _bufferTimer?.cancel();
    _progressTimer?.cancel();
    _hideControlsTimer?.cancel();
    _player.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Player de vídeo (sempre presente, mas oculto durante pré-buffer)
          AnimatedOpacity(
            opacity: _isPreBuffering ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 500),
            child: GestureDetector(
              onTap: _toggleControls,
              child: SizedBox.expand(
                child: Video(controller: _controller),
              ),
            ),
          ),

          // Overlay de pré-buffer
          if (_isPreBuffering) _buildPreBufferOverlay(),

          // Controles do player (visíveis quando não está em pré-buffer)
          if (!_isPreBuffering)
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildControls(),
            ),
        ],
      ),
    );
  }

  Widget _buildPreBufferOverlay() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo ou ícone do canal
              if (widget.logo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.logo!,
                      height: 64,
                      width: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.tv,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Icon(Icons.tv, color: Colors.white38, size: 48),
                ),

              // Nome do canal
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
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
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFB71C1C), // vermelho DreamServer
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Botão cancelar
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

  Widget _buildControls() {
    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0.0, 0.25, 0.75, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Top bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botão retry
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: 'Recarregar',
                    onPressed: _retry,
                  ),
                  const SizedBox(width: 8),
                  // Fullscreen
                  IconButton(
                    icon: Icon(
                      _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white70,
                    ),
                    tooltip: _isFullscreen ? 'Sair do fullscreen' : 'Fullscreen',
                    onPressed: _toggleFullscreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
