import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/market_post_model.dart';
import 'package:lockerroom/page/afterMarket/after_market_edit_page.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/afterMarket/after_market_detail_page.dart';
import 'package:lockerroom/page/afterMarket/after_market_upload_page.dart';
import 'package:lockerroom/page/login/login_page.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:lockerroom/provider/market_feed_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class AfterMarket extends StatefulWidget {
  final MarketPostModel? marketPost;
  const AfterMarket({super.key, this.marketPost});

  @override
  State<AfterMarket> createState() => _AfterMarketState();
}

class _AfterMarketState extends State<AfterMarket> {
  final ScrollController _listScrollController = ScrollController();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late MarketFeedProvider _marketFeedProvider;
  BlockProvider? _blockProvider;
  VoidCallback? _blockListener;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      });
    } else {
      // 실시간 리스너 시작
      _marketFeedProvider = context.read<MarketFeedProvider>();
      _marketFeedProvider.marketPostStream(user.uid);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _blockProvider = context.read<BlockProvider>();
        // 초기 동기화
        _marketFeedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
        _marketFeedProvider.setBlockedByUsers(_blockProvider!.blockedByUserIds);
        // 차단 목록 변경 리스너
        _blockListener = () {
          if (mounted) {
            _marketFeedProvider.setBlockedUsers(_blockProvider!.blockedUserIds);
            _marketFeedProvider.setBlockedByUsers(
              _blockProvider!.blockedByUserIds,
            );
          }
        };
        _blockProvider!.addListener(_blockListener!);
      });
    }

    _listScrollController.addListener(() {
      if (!_listScrollController.hasClients) return;
      final position = _listScrollController.position;
      if (position.pixels >= position.maxScrollExtent - 200) {
        // 더 이상 페이지네이션이 필요 없음 (실시간 리스너로 모든 데이터 받음)
      }
    });
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _searchController.dispose();
    if (_blockListener != null && _blockProvider != null) {
      _blockProvider!.removeListener(_blockListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '더베이스 마켓',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  // 검색 종료 시 검색어 초기화
                  Provider.of<MarketFeedProvider>(
                    context,
                    listen: false,
                  ).setQuery('');
                }
                _isSearching = !_isSearching;
              });
            },
            icon: _isSearching ? Icon(Icons.close) : Icon(Icons.search),
          ),
        ],
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                    child: TextFormField(
                      controller: _searchController,
                      cursorColor: BUTTON,
                      cursorHeight: 18,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      enableIMEPersonalizedLearning: true,
                      style: TextStyle(decoration: TextDecoration.none),
                      onChanged: (value) {
                        setState(() => _query = value);
                        context.read<MarketFeedProvider>().setQuery(value);
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        labelText: '검색어를 입력해주세요',
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
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
                  ),
                Expanded(
                  child: Consumer<MarketFeedProvider>(
                    builder: (context, marketFeed, child) {
                      if (marketFeed.isLoading) {
                        return Center(
                          child: CircularProgressIndicator(color: BUTTON),
                        );
                      }

                      final posts = _query.isEmpty
                          ? marketFeed.marketPostsStream
                          : marketFeed.marketPostsStream
                                .where(
                                  (p) => p.title.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ),
                                )
                                .toList();

                      if (posts.isEmpty) {
                        return Center(
                          child: Text(
                            '게시물이 없습니다',
                            style: TextStyle(color: GRAYSCALE_LABEL_500),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: _listScrollController,
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          return MarketPostWidget(
                            marketPost: posts[index],
                            merketFeed: marketFeed,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AfterMarketUploadPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: BUTTON,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(Icons.add, color: WHITE),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MarketPostWidget extends StatefulWidget {
  final MarketPostModel marketPost;
  final MarketFeedProvider merketFeed;
  final VoidCallback? onTap;

  const MarketPostWidget({
    required this.marketPost,
    required this.merketFeed,
    this.onTap,
    super.key,
  });

  @override
  State<MarketPostWidget> createState() => _MarketPostsWidgetState();
}

class _MarketPostsWidgetState extends State<MarketPostWidget> {
  String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner =
        currentUserId != null && widget.marketPost.userId == currentUserId;
    final mp = context.read<MarketFeedProvider>();
    return GestureDetector(
      onTap: () {
        // 조회수 증가
        context.read<MarketFeedProvider>().viewPost(widget.marketPost.postId);
        widget.onTap?.call();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AfterMarketDetailPage(
              marketPost: widget.marketPost,
              postId: widget.marketPost.postId,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 5, right: 5, bottom: 15),
        child: Container(
          decoration: BoxDecoration(
            color: WHITE,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GRAYSCALE_LABEL_200),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: widget.marketPost.imageUrls.isNotEmpty
                      ? Image.network(
                          widget.marketPost.imageUrls[0],
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.marketPost.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          onPressed: () {
                            _showPostOptionBottomSheet(context, mp, isOwner);
                          },
                          icon: Icon(Icons.more_horiz),
                        ),
                      ],
                    ),

                    Transform.translate(
                      offset: Offset(0, -10),
                      child: Text(
                        timeAgo(widget.marketPost.createdAt),
                        style: TextStyle(
                          color: GRAYSCALE_LABEL_500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.marketPost.type == '무료나눔')
                          Text(
                            '나눔',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          Text(
                            '${widget.marketPost.price}원',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPostOptionBottomSheet(
    BuildContext context,
    MarketFeedProvider mfp,
    bool isOwner,
  ) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: GRAYSCALE_LABEL_50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 200,
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              if (isOwner) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // 바텀시트 닫기
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AfterMarketEditPage(marketPost: widget.marketPost),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '게시물 수정',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Icon(Icons.edit_outlined, color: BLACK),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // 바텀시트 닫기
                    showDialog(
                      context: context,
                      builder: (context) => ConfirmationDialog(
                        title: '삭제 확인',
                        content: '게시물을 삭제 하시겠습니까?',
                        onConfirm: () async {
                          await mfp.deletePost(widget.marketPost);
                          toastification.show(
                            context: context,
                            type: ToastificationType.success,
                            alignment: Alignment.bottomCenter,
                            autoCloseDuration: Duration(seconds: 2),
                            title: Text('게시물을 삭제했습니다'),
                          );
                        },
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '게시물 삭제',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: RED_DANGER_TEXT_50,
                          ),
                        ),
                        Icon(
                          CupertinoIcons.delete_solid,
                          color: RED_DANGER_TEXT_50,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: () {
                    final reporter = FirebaseAuth.instance.currentUser;
                    if (reporter == null) {
                      toastification.show(
                        context: context,
                        type: ToastificationType.error,
                        alignment: Alignment.bottomCenter,
                        autoCloseDuration: Duration(seconds: 2),
                        title: Text('로그인이 필요합니다'),
                      );
                      return;
                    }
                    Navigator.pop(context); // 바텀시트 닫기
                    _showMarketFeedReportDialog(
                      context,
                      widget.marketPost,
                      mfp,
                      reporter.uid,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '게시물 신고',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: RED_DANGER_TEXT_50,
                          ),
                        ),
                        Icon(Icons.report_outlined, color: RED_DANGER_TEXT_50),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    Navigator.pop(context); // 바텀시트 닫기
                    _showBlockConfirmDialog(
                      context,
                      widget.marketPost.userNickName,
                      widget.marketPost.userId,
                      uid,
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '사용자 차단',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: RED_DANGER_TEXT_50,
                          ),
                        ),
                        Icon(
                          Icons.person_off_outlined,
                          color: RED_DANGER_TEXT_50,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMarketFeedReportDialog(
    BuildContext context,
    MarketPostModel marketPost,
    MarketFeedProvider marketFeedProvider,
    String currentUserId,
  ) {
    final TextEditingController reportController = TextEditingController();
    final List<String> reportReasons = [
      '스팸 및 광고',
      '부적절한 콘텐츠',
      '혐오 표현',
      '욕설 및 음란물',
      '개인정보 침해',
      '기타',
    ];
    String selectedReason = reportReasons[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BACKGROUND_COLOR,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 바
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '게시물 신고',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  '신고 사유를 선택해주세요',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                ...reportReasons.map((reason) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedReason = reason;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedReason == reason
                              ? BUTTON
                              : GRAYSCALE_LABEL_400,
                          width: selectedReason == reason ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: selectedReason == reason
                            ? BUTTON.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(reason)),
                          if (selectedReason == reason)
                            Icon(Icons.check, color: BUTTON),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                SizedBox(height: 16),
                Text(
                  '추가 설명 (선택사항)',
                  style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: reportController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '자세한 내용을 입력해주세요',
                    hintStyle: TextStyle(color: GRAYSCALE_LABEL_400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: GRAYSCALE_LABEL_400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: BUTTON),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: GRAYSCALE_LABEL_300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: GRAYSCALE_LABEL_900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final description = reportController.text.trim();
                          final reason =
                              selectedReason +
                              (description.isNotEmpty ? '\n$description' : '');

                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              Navigator.pop(context);
                              toastification.show(
                                context: context,
                                type: ToastificationType.error,
                                alignment: Alignment.bottomCenter,
                                autoCloseDuration: Duration(seconds: 2),
                                title: Text('로그인이 필요합니다'),
                              );
                              return;
                            }

                            await marketFeedProvider.reportMarketPost(
                              marketPost: marketPost,
                              reporterUserId: user.uid,
                              reporterUserNickName: user.displayName ?? '익명',
                              reason: reason,
                            );

                            if (!mounted) return;
                            Navigator.pop(context);
                            toastification.show(
                              context: context,
                              type: ToastificationType.success,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              title: Text('신고가 접수되었습니다'),
                            );
                          } catch (e) {
                            Navigator.pop(context);
                            toastification.show(
                              context: context,
                              type: ToastificationType.error,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              title: Text('신고 중 오류가 발생했습니다'),
                            );
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: RED_DANGER_TEXT_50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '신고하기',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: WHITE,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 사용자 차단 다이얼로그
  void _showBlockConfirmDialog(
    BuildContext context,
    String userNickName,
    String userId,
    String currentUserId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BACKGROUND_COLOR,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              // 상단 바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),

              // 제목
              Text(
                '${userNickName}님을\n차단하시겠어요?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),

              // 설명 텍스트
              Text(
                '이 사람이 만든 다른 계정과 앞으로 만드는 모든 계정이 함께 차단됩니다. 언제든지 차단을 해제할 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: GRAYSCALE_LABEL_600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // 차단 효과 설명
              _buildBlockEffectItem(
                icon: Icons.search_off,
                title: '게시물 및 프로필 숨김',
                description: '해당 사용자는 회원님의 프로필과 게시물을 찾을 수 없습니다.',
              ),
              SizedBox(height: 16),

              _buildBlockEffectItem(
                icon: Icons.comment,
                title: '상호작용 차단',
                description: '해당 사용자가 남긴 댓글은 회원님에게 보이지 않습니다.',
              ),
              SizedBox(height: 16),

              _buildBlockEffectItem(
                icon: Icons.mail,
                title: '메시지 차단',
                description: '해당 사용자는 직접 메시지를 보낼 수 없습니다.',
              ),
              SizedBox(height: 16),

              _buildBlockEffectItem(
                icon: Icons.notifications_off,
                title: '상대방에게 알림 없음',
                description: '상대방에게 회원님이 차단했다는 사실을 알리지 않습니다.',
              ),
              SizedBox(height: 28),

              // 버튼
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: GRAYSCALE_LABEL_300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: GRAYSCALE_LABEL_900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final bottomSheetContext = context;
                        try {
                          await context.read<BlockProvider>().blockUser(
                            currentUserId: currentUserId,
                            targetUserId: userId,
                          );
                          Future.delayed(Duration.zero, () {
                            Navigator.pop(bottomSheetContext);
                            toastification.show(
                              context: bottomSheetContext,
                              type: ToastificationType.success,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              title: Text('${userNickName}님을 차단했습니다'),
                            );
                          });
                          if (!mounted) return;
                        } catch (e) {
                          Future.delayed(Duration.zero, () {
                            Navigator.pop(bottomSheetContext);
                            toastification.show(
                              context: bottomSheetContext,
                              type: ToastificationType.error,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              title: Text('차단 중 오류가 발생했습니다'),
                            );
                          });
                          if (!mounted) return;
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: RED_DANGER_TEXT_50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '차단',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: WHITE,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockEffectItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: GRAYSCALE_LABEL_600),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GRAYSCALE_LABEL_900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: GRAYSCALE_LABEL_600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
