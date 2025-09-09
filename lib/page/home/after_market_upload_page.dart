import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/const/priceFormatter.dart';
import 'package:lockerroom/provider/market_upload_provider.dart';
import 'package:provider/provider.dart';

class AfterMarketUploadPage extends StatefulWidget {
  final VoidCallback? onUploaded;
  const AfterMarketUploadPage({super.key, this.onUploaded});

  @override
  State<AfterMarketUploadPage> createState() => _AfterMarketUploadPageState();
}

class _AfterMarketUploadPageState extends State<AfterMarketUploadPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  // 거래유형 드롭다운 초기값
  String selectedValue = '직거래';

  final List<String> options = ['직거래', '택배', '무료나눔'];

  @override
  Widget build(BuildContext context) {
    final marketUploadProvider = Provider.of<MarketUploadProvider>(
      context,
      listen: true,
    );
    final hasCaption = _captionController.text.trim().isNotEmpty;
    final hasPrice = _priceController.text.trim().isNotEmpty;
    final hasImage =
        marketUploadProvider.images.isNotEmpty ||
        marketUploadProvider.camera != null;
    final canUpload =
        hasCaption && hasPrice && hasImage && !marketUploadProvider.isUploading;
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userName = FirebaseAuth.instance.currentUser!.displayName;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '글쓰기',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        scrolledUnderElevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final currentCount =
                            marketUploadProvider.images.length +
                            (marketUploadProvider.camera != null ? 1 : 0);
                        final remaining =
                            MarketUploadProvider.maxImages - currentCount;
                        if (remaining <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('이미지는 최대 10장까지 선택할 수 있어요.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        pickImageBottomSheet(context, marketUploadProvider);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: WHITE,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GRAYSCALE_LABEL_500),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.camera_alt),
                            Text('${marketUploadProvider.images.length}/10'),
                          ],
                        ),
                      ),
                    ),
                    // 이미지 미리보기
                    if (hasImage)
                      Expanded(
                        child: SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount:
                                marketUploadProvider.images.length +
                                (marketUploadProvider.camera != null ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index < marketUploadProvider.images.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: _buildImageItem(
                                    marketUploadProvider.images[index],
                                    isImage: true,
                                    marketUploadProvider: marketUploadProvider,
                                  ),
                                );
                              } else {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: _buildImageItem(
                                    marketUploadProvider.camera!,
                                    isCamera: true,
                                    isImage: true,
                                    marketUploadProvider: marketUploadProvider,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 20),
                Text(
                  '제목',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _captionController,
                  cursorColor: BUTTON,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: '글 제목',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '자세한 설명',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GRAYSCALE_LABEL_400),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 100, // 최소 높이 지정 가능
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      cursorColor: BUTTON,
                      maxLines: null,
                      minLines: 1,
                      textAlignVertical: TextAlignVertical.top, // 위쪽 정렬
                      decoration: const InputDecoration(
                        hintText: '판매 할 물건에 대한 자세한 설명을 해주세요',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        isDense: true, // 패딩 최소화
                        contentPadding: EdgeInsets.zero, // 내부 여백 완전히 제거
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '가격',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _priceController,
                  cursorColor: BUTTON,
                  keyboardType: TextInputType.number,
                  inputFormatters: [Priceformatter()],
                  decoration: InputDecoration(
                    labelText: '가격',
                    labelStyle: TextStyle(color: Colors.grey),
                    suffixText: '원',
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '거래 유형',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: WHITE,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButton<String>(
                    value: selectedValue,
                    dropdownColor: WHITE,
                    items: options
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => selectedValue = value);
                    },
                    underline: const SizedBox(),
                    isExpanded: true,
                  ),
                ),
                SizedBox(height: 40),
                // 등록하기 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: canUpload
                        ? () async {
                            await marketUploadProvider.uploadAndSavePost(
                              userId: userId,
                              userName: userName!,
                              title: _captionController.text,
                              price: _priceController.text,
                              description: _descriptionController.text,
                              type: selectedValue,
                            );
                            _captionController.clear();
                            _priceController.clear();
                            _descriptionController.clear();
                            widget.onUploaded?.call();

                            if (!mounted) return;
                            Navigator.pop(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BUTTON,
                      disabledBackgroundColor: GRAYSCALE_LABEL_300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: marketUploadProvider.isUploading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: WHITE,
                            ),
                          )
                        : const Text(
                            '업로드',
                            style: TextStyle(
                              color: WHITE,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<dynamic> pickImageBottomSheet(
    BuildContext context,
    MarketUploadProvider marketUploadProvider,
  ) {
    return showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GRAYSCALE_LABEL_50,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final currentCount =
            marketUploadProvider.images.length +
            (marketUploadProvider.camera != null ? 1 : 0);
        final remaining = MarketUploadProvider.maxImages - currentCount;
        final limitReached = remaining <= 0;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.perm_media, color: BUTTON),
                    SizedBox(width: 8),
                    Text(
                      '미디어 추가',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: BLACK,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      remaining > 0 ? '남은 ${remaining}장' : '최대 10장',
                      style: TextStyle(
                        color: remaining > 0
                            ? GRAYSCALE_LABEL_500
                            : RED_DANGER_TEXT_50,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(height: 1, color: GRAYSCALE_LABEL_200),
                SizedBox(height: 8),

                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: BUTTON.withOpacity(0.1),
                    child: Icon(Icons.camera_alt_rounded, color: BUTTON),
                  ),
                  title: Text(
                    '사진 촬영',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    limitReached ? '최대 10장까지 선택 가능합니다.' : '카메라로 바로 촬영합니다.',
                  ),
                  onTap: limitReached
                      ? null
                      : () async {
                          if (marketUploadProvider.isUploading) return;
                          await marketUploadProvider.pickCamera();
                          if (context.mounted) Navigator.pop(context);
                        },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: BUTTON.withOpacity(0.1),
                    child: Icon(Icons.photo, color: BUTTON),
                  ),
                  title: Text(
                    '사진 선택',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    limitReached ? '최대 10장까지 선택 가능합니다.' : '여러 장 선택할 수 있어요.',
                  ),
                  onTap: limitReached
                      ? null
                      : () async {
                          if (marketUploadProvider.isUploading) return;
                          await marketUploadProvider.pickImages();
                          if (context.mounted) Navigator.pop(context);
                        },
                ),
                SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '닫기',
                      style: TextStyle(color: GRAYSCALE_LABEL_500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageItem(
    File file, {
    required bool isImage,
    required MarketUploadProvider marketUploadProvider,
    bool isCamera = false,
  }) {
    Widget imageContent;

    if (isImage) {
      imageContent = Image.file(
        file,
        fit: BoxFit.cover,
        // cacheWidth: 300,
        // cacheHeight: 300,
        filterQuality: FilterQuality.medium,
      );
    } else {
      imageContent = Container(
        color: Colors.grey[300],
        child: Center(child: Icon(Icons.image, color: Colors.white, size: 20)),
      );
    }
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(aspectRatio: 1, child: imageContent),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: () {
                if (isCamera) {
                  marketUploadProvider.setCamera(null);
                } else {
                  final updated = List<File>.from(marketUploadProvider.images)
                    ..remove(file);
                  marketUploadProvider.setImages(updated);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, color: WHITE, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
