import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const _kRed = Color(0xFFE50914);

enum AspectMode { wide, fit, full }

class PlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  const PlayerScreen({super.key, required this.title, required this.url});

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
        AspectMode.fit => AspectMode.full,
        AspectMode.full => AspectMode.wide,
      };
    });
    _scheduleHide();
  }

  double? get _aspectRatio {
    switch (_aspectMode) {
      case AspectMode.wide: return 16 / 9;
      case AspectMode.fit: return 4 / 3;
      case AspectMode.full: return null;
    }
  }

  String get _aspectLabel {
    switch (_aspectMode) {
      case AspectMode.wide: return '16:9';
      case AspectMode.fit: return '4:3';
      case AspectMode.full: return 'Preencher';
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _hideTimer?.cancel();
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
          if (_buffering && !_error)
            const Center(child: CircularProgressIndicator(color: _kRed)),
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
                  Expanded(child: Text(widget.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                ]),
              ),
            ),
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
                        color: Colors.white,
                        size: 36,
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