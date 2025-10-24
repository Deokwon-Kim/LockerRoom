import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';

class DeclarationDiallog extends StatelessWidget {
  final String title;
  final String? cancelText;
  final String? confirmText;
  final void Function(String) onConfirm;
  final Color confirmColor;

  const DeclarationDiallog({
    super.key,
    required this.title,
    required this.onConfirm,
    this.cancelText,
    this.confirmText,
    this.confirmColor = RED_DANGER_TEXT_50,
  });

  @override
  Widget build(BuildContext context) {
    final reasonController = TextEditingController();
    return AlertDialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        title,
        style: const TextStyle(
          color: GRAYSCALE_LABEL_900,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        cursorColor: BUTTON,
        controller: reasonController,
        minLines: 1,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: '신고 사유를 입력하세요',
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: BUTTON),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: BUTTON),
          ),
          focusColor: BUTTON,
          fillColor: BUTTON,
        ),
      ),
      actionsPadding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      actions: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  overlayColor: Colors.transparent,
                  elevation: 0,
                  backgroundColor: GRAYSCALE_LABEL_100,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  cancelText ?? '아니요',
                  style: TextStyle(color: GRAYSCALE_LABEL_950),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: confirmColor,
                  overlayColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm(reasonController.text);
                },
                child: Text(
                  confirmText ?? '신고',
                  style: TextStyle(color: BLACK),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
