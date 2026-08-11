import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

const _kRed = Color(0xFFE50914);

enum AspectMode { fit, wide, full }

class PlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  const PlayerScreen({super.key, required this.title, required this.url});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _vpc;
  ChewieController? _cc;
  bool _error = false;
  AspectMode _aspectMode = AspectMode.wide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _init();
  }

  Future<void> _init() async {
    try {
      _vpc = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _vpc!.initialize();
      _buildChewie();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _buildChewie() {
    _cc?.dispose();
    double? aspect;
    if (_aspectMode == AspectMode.wide) aspect = 16 / 9;
    if (_aspectMode == AspectMode.fit) aspect = 4 / 3;
    // AspectMode.full = null (preenche tudo)

    _cc = ChewieController(
      videoPlayerController: _vpc!,
      autoPlay: true,
      allowFullScreen: false,
      allowMuting: true,
      showControls: true,
      aspectRatio: aspect,
      placeholder: const Center(child: CircularProgressIndicator(color: _kRed)),
    );
  }

  void _cycleAspect() {
    setState(() {
      if (_aspectMode == AspectMode.wide) _aspectMode = AspectMode.fit;
      else if (_aspectMode == AspectMode.fit) _aspectMode = AspectMode.full;
      else _aspectMode = AspectMode.wide;
      if (_vpc != null && _vpc!.value.isInitialized) _buildChewie();
    });
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
    _cc?.dispose();
    _vpc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Video
        Center(
          child: _error
              ? const Text('Erro ao carregar stream.', style: TextStyle(color: Colors.white))
              : _cc == null
                  ? const CircularProgressIndicator(color: _kRed)
                  : Chewie(controller: _cc!),
        ),
        // Top bar
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
              // Aspect ratio button
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
      ]),
    );
  }
}
