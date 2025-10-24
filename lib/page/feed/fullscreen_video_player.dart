import 'package:flutter/material.dart';
import 'package:lockerroom/widgets/network_video_player.dart';

class FullscreenVideoPlayer extends StatelessWidget {
  final String videoUrl;

  const FullscreenVideoPlayer({Key? key, required this.videoUrl})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: NetworkVideoPlayer(
          videoUrl: videoUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          autoPlay: true,
          muted: false,
          showControls: true,
        ),
      ),
    );
  }
}
