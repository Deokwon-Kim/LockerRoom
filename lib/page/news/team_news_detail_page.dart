import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_news_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/widgets/team_news_section.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TeamNewsDetailPage extends StatefulWidget {
  final TeamNewsModel? article;
  final String? url;
  final String? title;
  final String? source;
  final NewsCategory? category;
  final Color? teamColor;

  const TeamNewsDetailPage({
    super.key,
    this.article,
    this.url,
    this.title,
    this.source,
    this.category,
    this.teamColor,
  }) : assert(article != null || url != null, 'article 또는 url 중 하나는 필수입니다.');

  const TeamNewsDetailPage.fromUrl({
    super.key,
    required String this.url,
    this.title,
    this.source,
    this.category,
    this.teamColor,
  }) : article = null;

  @override
  State<TeamNewsDetailPage> createState() => _TeamNewsDetailPageState();
}

class _TeamNewsDetailPageState extends State<TeamNewsDetailPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _hasError = false;
  String? _errorDescription;

  String get _targetUrl => widget.article?.url ?? widget.url ?? '';

  String get _displayTitle =>
      widget.article?.title ?? widget.title ?? '구단 뉴스 상세';

  String get _displaySource =>
      widget.article?.source ?? widget.source ?? '뉴스 원문';

  NewsCategory? get _displayCategory =>
      widget.article?.category ?? widget.category;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(WHITE)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _hasError = false;
              _errorDescription = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            if (error.isForMainFrame ?? true) {
              setState(() {
                _hasError = true;
                _errorDescription = error.description;
              });
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && uri.scheme != 'http' && uri.scheme != 'https') {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    final initialUri = Uri.tryParse(_targetUrl);
    if (initialUri != null && initialUri.hasScheme) {
      _controller.loadRequest(initialUri);
    } else {
      _hasError = true;
      _errorDescription = '유효하지 않은 기사 URL입니다.';
    }
  }

  Future<void> _openExternalBrowser() async {
    final uri = Uri.tryParse(_targetUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _reloadPage() {
    final uri = Uri.tryParse(_targetUrl);
    if (uri == null || !uri.hasScheme) return;
    setState(() {
      _hasError = false;
      _errorDescription = null;
      _progress = 0;
    });
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final teamSymple = widget.article?.teamSymple;
    final resolvedTeamColor =
        widget.teamColor ??
        (teamSymple != null && teamSymple.isNotEmpty
            ? context.read<TeamProvider>().findTeamByName(teamSymple)?.color
            : null) ??
        BUTTON;

    final category = _displayCategory;

    return Scaffold(
      backgroundColor: WHITE,
      appBar: AppBar(
        backgroundColor: WHITE,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: '뒤로가기',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: BLACK,
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 3.5,
              height: 28,
              decoration: BoxDecoration(
                color: resolvedTeamColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (category != null) ...[
                        NewsCategoryBadge(category: category),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          _displaySource,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: GRAYSCALE_LABEL_600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: BLACK,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _reloadPage,
            tooltip: '새로고침',
            icon: const Icon(
              Icons.refresh_rounded,
              size: 21,
              color: GRAYSCALE_LABEL_800,
            ),
          ),
          IconButton(
            onPressed: _openExternalBrowser,
            tooltip: '외부 브라우저로 열기',
            icon: const Icon(
              Icons.open_in_new_rounded,
              size: 20,
              color: GRAYSCALE_LABEL_800,
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _progress < 100 && !_hasError
              ? LinearProgressIndicator(
                  value: _progress / 100.0,
                  minHeight: 3,
                  backgroundColor: GRAYSCALE_LABEL_100,
                  valueColor: AlwaysStoppedAnimation<Color>(resolvedTeamColor),
                )
              : Container(height: 1, color: GRAYSCALE_LABEL_100),
        ),
      ),
      body: _hasError
          ? _buildErrorView(resolvedTeamColor)
          : WebViewWidget(controller: _controller),
    );
  }

  Widget _buildErrorView(Color accentColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: RED_DANGER_SURFACE_5,
                shape: BoxShape.circle,
                border: Border.all(color: RED_DANGER_BORDER_10),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: RED_DANGER_TEXT_50,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '기사를 불러오지 못했습니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: BLACK,
              ),
            ),
            if (_errorDescription != null && _errorDescription!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _errorDescription!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: GRAYSCALE_LABEL_500,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _reloadPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: WHITE,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    '다시 시도',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _openExternalBrowser,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GRAYSCALE_LABEL_800,
                    side: const BorderSide(color: GRAYSCALE_LABEL_200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text(
                    '외부 브라우저',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
