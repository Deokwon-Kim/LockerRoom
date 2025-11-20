import 'package:flutter/material.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:lockerroom/const/color.dart';

class NetworkVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool autoPlay;
  final bool showControls;
  final bool muted;

  const NetworkVideoPlayer({
    Key? key,
    required this.videoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.autoPlay = true,
    this.showControls = false,
    this.muted = true,
  }) : super(key: key);

  @override
  State<NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<NetworkVideoPlayer>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isVisible = true;
  bool _isMuted = false;
  final String _visibilityKey = DateTime.now().millisecondsSinceEpoch
      .toString();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(NetworkVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _isInitialized = false;
      });

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      _controller!.addListener(_videoListener);

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });

        // 음소거 설정
        if (widget.muted) {
          await _controller!.setVolume(0.0);
          setState(() {
            _isMuted = true;
          });
        } else {
          setState(() {
            _isMuted = false;
          });
        }

        // 자동 재생
        if (widget.autoPlay) {
          await _controller!.play();
          await _controller!.setLooping(true);
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      debugPrint('동영상 플레이어 초기화 에러: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller != null && mounted) {
      final bool isPlaying = _controller!.value.isPlaying;
      if (_isPlaying != isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    }
  }

  void _togglePlayPause() async {
    if (_controller != null && _isInitialized) {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
    }
  }

  Future<void> _toggleMute() async {
    if (_controller != null && _isInitialized) {
      setState(() {
        _isMuted = !_isMuted;
      });

      if (_isMuted) {
        await _controller!.setVolume(0.0);
      } else {
        await _controller!.setVolume(1.0);
      }
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted || _controller == null || !_isInitialized) return;

    final bool wasVisible = _isVisible;
    _isVisible = info.visibleFraction > 0.5; // 50% 이상 보일 때 재생

    if (_isVisible && !wasVisible && widget.autoPlay) {
      // 화면에 보이게 되면 재생
      _controller!.play();
    } else if (!_isVisible && wasVisible) {
      // 화면에서 사라지면 일시정지
      _controller!.pause();
    }
  }

  Widget _buildLoadingWidget() {
    final selectedTeam = Provider.of<TeamProvider>(
      context,
      listen: false,
    ).selectedTeam;
    final teamColor = selectedTeam?.color ?? BUTTON;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: teamColor, strokeWidth: 2),
          const SizedBox(height: 8),
          const Text(
            '동영상 로딩 중...',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_file, size: 40, color: Colors.grey),
                SizedBox(height: 4),
                Text(
                  '동영상을 로드할 수 없습니다',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // 재생 아이콘 오버레이
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
            // 컨트롤 오버레이 (필요한 경우에만)
            if (widget.showControls)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // 무음 표시 아이콘
            if (widget.muted)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = _buildLoadingWidget();
    } else if (_hasError || !_isInitialized || _controller == null) {
      content = _buildErrorWidget();
    } else {
      content = _buildVideoPlayer();
    }

    return Container(
      width: widget.width,
      height: widget.height,
      child: VisibilityDetector(
        key: Key(_visibilityKey),
        onVisibilityChanged: _onVisibilityChanged,
        child: content,
      ),
    );
  }
}
