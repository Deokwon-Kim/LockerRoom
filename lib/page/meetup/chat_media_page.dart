import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/feed/fullscreen_image_viewer.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class ChatMediaPage extends StatelessWidget {
  final List<types.ImageMessage> images;
  final String title;

  const ChatMediaPage({
    super.key,
    required this.images,
    this.title = '사진 모아보기',
  });

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();
    return Scaffold(
      backgroundColor: WHITE,
      appBar: AppBar(
        backgroundColor: WHITE,
        foregroundColor: BLACK,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: images.isEmpty
          ? const Center(
              child: Text(
                '공유된 사진이 없습니다',
                style: TextStyle(color: GRAYSCALE_LABEL_400),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final msg = images[index];
                final bool isLocal =
                    msg.metadata?['isLocal'] == true || msg.uri.startsWith('/');

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FullscreenImageViewer(
                          imageUrls: images.map((m) => m.uri).toList(),
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'chat_media_${msg.id}',
                    child: Container(
                      decoration: BoxDecoration(color: GRAYSCALE_LABEL_100),
                      child: isLocal
                          ? Image.file(
                              File(msg.uri),
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                            )
                          : Image.network(
                              msg.uri,
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: teamProvider.selectedTeam?.color,
                                        strokeWidth: 2,
                                        value:
                                            loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: GRAYSCALE_LABEL_400,
                                    ),
                                  ),
                            ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
