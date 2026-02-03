import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomLinkPreview extends StatefulWidget {
  final String text; // URL
  final String meetupId;
  final String messageId;
  final Map<String, dynamic>? metadata;

  const CustomLinkPreview({
    super.key,
    required this.text,
    required this.meetupId,
    required this.messageId,
    this.metadata,
  });

  @override
  State<CustomLinkPreview> createState() => _CustomLinkPreviewState();
}

class _CustomLinkPreviewState extends State<CustomLinkPreview> {
  LinkPreviewData? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant CustomLinkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _loadData();
    }
  }

  // 메타데이터에서 로드하거나 새로 가져오기
  Future<void> _loadData() async {
    // 1. 메타데이터 확인
    if (widget.metadata != null && widget.metadata!['previewData'] != null) {
      try {
        final map = widget.metadata!['previewData'];
        // Map -> LinkPreviewData 변환
        _data = LinkPreviewData(
          link: map['link'],
          title: map['title'],
          description: map['description'],
          image: map['image'] != null
              ? ImagePreviewData(
                  url: map['image']['url'],
                  width: (map['image']['width'] as num).toDouble(),
                  height: (map['image']['height'] as num).toDouble(),
                )
              : null,
        );
        if (mounted) setState(() {});
        return;
      } catch (e) {
        debugPrint('Metadata parse error: $e');
      }
    }

    // 2. 없으면 새로 가져오기
    if (_loading) return;
    setState(() {
      _loading = true;
    });

    try {
      final data = await getLinkPreviewData(widget.text);
      if (data != null) {
        if (!mounted) return;
        setState(() {
          _data = data;
          _loading = false;
        });

        // 3. Firestore 저장 (Map으로 변환)
        final previewMap = {
          'link': data.link,
          'title': data.title,
          'description': data.description,
          'image': data.image != null
              ? {
                  'url': data.image!.url,
                  'width': data.image!.width,
                  'height': data.image!.height,
                }
              : null,
        };

        final newMetadata = Map<String, dynamic>.from(widget.metadata ?? {});
        newMetadata['previewData'] = previewMap;

        // context.read 호출을 Future 이후에 할 때 mounted 체크
        if (mounted) {
          context.read<ChatProvider>().updateMessageMetadata(
            widget.meetupId,
            widget.messageId,
            newMetadata,
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Preview load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      // 로딩 중이거나 데이터 없을 땐 아무것도 안 보여줌
      return const SizedBox.shrink();
    }

    final data = _data!;
    final hasImage = data.image?.url != null;

    // UI 디자인
    return GestureDetector(
      onTap: () {
        if (data.link.isNotEmpty) {
          launchUrl(Uri.parse(data.link), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        width: 300,
        decoration: BoxDecoration(
          color: WHITE, // 짙은 회색 배경
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지
            if (hasImage)
              Image.network(
                data.image!.url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),

            // 텍스트 영역
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.title != null)
                    Text(
                      data.title!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (data.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      data.description!,
                      style: const TextStyle(
                        color: Color(0xFFAAAAAA), // 연한 회색
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // 도메인 표시 (Url parsing)
                  if (data.link.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.public, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            Uri.parse(data.link).host,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
