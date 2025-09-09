import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/market_post_model.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:provider/provider.dart';

class AfterMarketDetailPage extends StatefulWidget {
  final MarketPostModel marketPost;
  const AfterMarketDetailPage({super.key, required this.marketPost});

  @override
  State<AfterMarketDetailPage> createState() => _AfterMarketDetailPageState();
}

class _AfterMarketDetailPageState extends State<AfterMarketDetailPage> {
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
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          widget.marketPost.title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.more_vert_rounded)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CarouselSlider.builder(
              itemCount: widget.marketPost.imageUrls.length,
              itemBuilder: (context, index, realIndex) {
                final url = widget.marketPost.imageUrls[index];
                return Image.network(url, fit: BoxFit.cover, width: 1000);
              },
              options: CarouselOptions(
                height: 350,
                viewportFraction: 1.0,
                enlargeCenterPage: false,
                autoPlay: false,
                enableInfiniteScroll:
                    widget.marketPost.imageUrls.length > 1, // 무한 스크롤 막기
                scrollPhysics: widget.marketPost.imageUrls.length > 1
                    ? const PageScrollPhysics() // 이미지가 여러개일때만 스와이프 허용
                    : const NeverScrollableScrollPhysics(), // 이미지 하나일땐 스와이프 막음
              ),
            ),
            Container(
              color: BACKGROUND_COLOR,
              width: double.infinity,
              height: 50,
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Row(
                  children: [
                    Consumer<ProfileProvider>(
                      builder: (context, profileProvider, child) {
                        final url = profileProvider
                            .userProfiles[widget.marketPost.userId];
                        return CircleAvatar(
                          radius: 15,
                          backgroundImage: url != null
                              ? NetworkImage(url)
                              : null,
                          backgroundColor: GRAYSCALE_LABEL_300,
                          child: url == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.black,
                                  size: 25,
                                )
                              : null,
                        );
                      },
                    ),
                    SizedBox(width: 10),
                    Text(widget.marketPost.userName),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: GRAYSCALE_LABEL_200),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.marketPost.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeAgo(widget.marketPost.createdAt),
                        style: TextStyle(
                          color: GRAYSCALE_LABEL_500,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  if (widget.marketPost.type == '택배')
                    Chip(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      label: Text('택배', style: TextStyle(color: WHITE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Colors.green,
                    )
                  else if (widget.marketPost.type == '직거래')
                    Chip(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      label: const Text('직거래', style: TextStyle(color: WHITE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Doosan,
                    )
                  else if (widget.marketPost.type == '무료나눔')
                    Chip(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      label: Text('나눔', style: TextStyle(color: WHITE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Samsung,
                    ),
                  Text(
                    '${widget.marketPost.price}원',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 15),
                  Text('${widget.marketPost.description}'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '댓글을 입력하세요...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              IconButton(onPressed: () {}, icon: Icon(Icons.send)),
            ],
          ),
        ),
      ),
    );
  }
}
