import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/const/priceFormatter.dart';

class AfterMarketUploadPage extends StatefulWidget {
  const AfterMarketUploadPage({super.key});

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
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GRAYSCALE_LABEL_500),
                    ),
                    child: Column(
                      children: [Icon(Icons.camera_alt), Text('0/10')],
                    ),
                  ),
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
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButton<String>(
                    value: selectedValue,
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
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BUTTON,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '등록하기',
                      style: TextStyle(
                        color: WHITE,
                        fontSize: 18,
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
}
