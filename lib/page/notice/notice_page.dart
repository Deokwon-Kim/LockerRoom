import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/notice/notice_edit_page.dart';
import 'package:lockerroom/page/notice/notice_view_page.dart';

class NoticePage extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final String? noticeId;
  final bool isAdmin;
  const NoticePage({
    super.key,
    this.initialTitle,
    this.initialContent,
    this.noticeId,
    this.isAdmin = false,
  });

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  bool _isEditing = true;
  String _savedTitle = "";
  String _savedContent = "";
  String _noticeDate = "";

  @override
  void initState() {
    super.initState();
    _noticeDate = DateFormat('yyyy.MM.dd').format(DateTime.now());

    if (widget.initialTitle != null) {
      _savedTitle = widget.initialTitle!;
      _savedContent = widget.initialContent!;
      _isEditing = false; // 초기값이 있으면 보기 모드로 시작
    }
  }

  void _switchToEditMode() {
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          title: '공지사항 삭제',
          content: '공지사항을 삭제합니다.',
          confirmText: '삭제',
          cancelText: '취소',
          onConfirm: () {
            Navigator.of(context).pop();
            Navigator.pop(context, {'delete': true});
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: GRAYSCALE_LABEL_950),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "공지사항",
          style: TextStyle(
            color: GRAYSCALE_LABEL_950,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: _isEditing
          ? NoticeEditPage(
              initialTitle: _savedTitle,
              initialContent: _savedContent,
              noticeId: widget.noticeId,
              isAdmin: widget.isAdmin,
            )
          : NoticeViewPage(
              title: _savedTitle,
              content: _savedContent,
              date: _noticeDate,
              onEdit: widget.isAdmin ? _switchToEditMode : null,
              onDelete: widget.isAdmin ? _showDeleteConfirmationDialog : null,
            ),
    );
  }
}
