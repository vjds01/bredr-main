import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../services/cloudinary_service.dart';
import '../theme/app_colors.dart';

class BreedrVideoCard extends StatefulWidget {
  const BreedrVideoCard({super.key, required this.url});

  final String url;

  @override
  State<BreedrVideoCard> createState() => _BreedrVideoCardState();
}

class _BreedrVideoCardState extends State<BreedrVideoCard>
    with WidgetsBindingObserver {
  static _BreedrVideoCardState? _activePlayer;

  VideoPlayerController? _controller;
  Object? _error;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(CloudinaryService.compatibleVideoUrl(widget.url)),
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _initializing = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _pause() {
    _controller?.pause();
    if (_activePlayer == this) _activePlayer = null;
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      _pause();
      return;
    }

    _activePlayer?._pause();
    _activePlayer = this;
    if (controller.value.position >= controller.value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
    if (mounted) setState(() {});
  }

  Future<void> _openExternally() async {
    await launchUrl(
      Uri.parse(CloudinaryService.compatibleVideoUrl(widget.url)),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_activePlayer == this) _activePlayer = null;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _initializing
          ? const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : _error != null || controller == null
          ? _VideoFailure(onOpen: _openExternally)
          : ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final durationMs = value.duration.inMilliseconds;
                final positionMs = value.position.inMilliseconds.clamp(
                  0,
                  durationMs,
                );
                final finished =
                    durationMs > 0 && positionMs >= durationMs - 250;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: value.aspectRatio == 0
                          ? 16 / 9
                          : value.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          VideoPlayer(controller),
                          Center(
                            child: IconButton.filled(
                              onPressed: _togglePlayback,
                              iconSize: 38,
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause
                                    : finished
                                    ? Icons.replay
                                    : Icons.play_arrow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: positionMs.toDouble(),
                            max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                            onChanged: durationMs <= 0
                                ? null
                                : (value) => controller.seekTo(
                                    Duration(milliseconds: value.round()),
                                  ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Open Video',
                          onPressed: _openExternally,
                          color: Colors.white,
                          icon: const Icon(Icons.open_in_new),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _VideoFailure extends StatelessWidget {
  const _VideoFailure({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 8),
          const Text(
            'Unable to load video',
            style: TextStyle(color: Colors.white),
          ),
          TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Video'),
          ),
        ],
      ),
    );
  }
}
