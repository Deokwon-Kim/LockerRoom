import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/market_post_model.dart';
import 'package:lockerroom/provider/marketFeedEdit_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class AfterMarketEditPage extends StatefulWidget {
  final MarketPostModel marketPost;
  const AfterMarketEditPage({super.key, required this.marketPost});

  @override
  State<AfterMarketEditPage> createState() => _AfterMarketEditPageState();
}

class _AfterMarketEditPageState extends State<AfterMarketEditPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;

  final List<String> options = ['직거래', '택배', '무료나눔'];
  late String selectedValue;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.marketPost.title);
    _priceController = TextEditingController(text: widget.marketPost.price);
    _descriptionController = TextEditingController(
      text: widget.marketPost.description,
    );
    selectedValue = widget.marketPost.type;

    // Provider 초기화 - build 후에 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketfeededitProvider>().initializeEdit(widget.marketPost);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '게시물 수정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Consumer2<MarketfeededitProvider, TeamProvider>(
            builder: (context, mfp, tp, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: GestureDetector(
                  onTap: mfp.isUploading
                      ? null
                      : () async {
                          final success = await mfp.updateMarketPost(
                            postId: widget.marketPost.postId,
                            newtitle: _titleController.text,
                            newDesc: _descriptionController.text,
                            newPrice: _priceController.text,
                            newType: selectedValue,
                          );
                          if (success) {
                            Navigator.pop(context);
                            toastification.show(
                              context: context,
                              type: ToastificationType.success,
                              style: ToastificationStyle.flat,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              title: Text('게시물 수정이 완료되었습니다.'),
                            );
                          }
                        },
                  child: mfp.isUploading
                      ? CircularProgressIndicator(color: tp.selectedTeam?.color)
                      : Text(
                          '완료',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: BUTTON,
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<MarketfeededitProvider>(
              builder: (context, mfep, child) {
                return SizedBox(
                  height: 80,
                  child: mfep.editImageUrls.isEmpty
                      ? Center(
                          child: Text(
                            '이미지가 없습니다',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: mfep.editImageUrls.length,
                          itemBuilder: (context, index) {
                            final imgUrl = mfep.editImageUrls[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    clipBehavior: Clip.hardEdge,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Image.network(
                                      imgUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () {
                                        mfep.removeImage(index);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: WHITE,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                );
              },
            ),
            SizedBox(height: 20),
            Text(
              '제목',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _titleController,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: '가격',
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
          ],
        ),
      ),
    );
  }
}
