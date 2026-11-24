import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lockerroom/model/team_news_model.dart';

class TeamNewsService {
  static const Map<String, String> _teamQueryMap = {
    '두산': '두산 베어스 야구',
    '삼성': '삼성 라이온즈 야구',
    '롯데': '롯데 자이언츠 야구',
    '기아': 'KIA 타이거즈 야구',
    'kia': 'KIA 타이거즈 야구',
    'lg': 'LG 트윈스 야구',
    'ssg': 'SSG 랜더스 야구',
    'sk': 'SSG 랜더스 야구',
    '한화': '한화 이글스 야구',
    '키움': '키움 히어로즈 야구',
    '넥센': '키움 히어로즈 야구',
    'nc': 'NC 다이노스 야구',
    'kt': 'KT 위즈 야구',
  };

  Future<List<TeamNewsModel>> fetchTeamNews(
    String teamSymple, {
    int limit = 25,
  }) async {
    final key = teamSymple.trim().toLowerCase();
    final query = _teamQueryMap[key] ?? '$teamSymple 프로야구 KBO';
    final uri = Uri.https('news.google.com', '/rss/search', {
      'q': query,
      'hl': 'ko',
      'gl': 'KR',
      'ceid': 'KR:ko',
    });

    final response = await http
        .get(
          uri,
          headers: const {
            'User-Agent': 'Mozilla/5.0 (compatible; ILUApp/1.0)',
            'Accept': 'application/rss+xml, application/xml, text/xml',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw HttpException('뉴스를 불러오지 못했습니다 (${response.statusCode})');
    }

    final xmlBody = utf8.decode(response.bodyBytes, allowMalformed: true);
    return _parseRssItems(xmlBody, teamSymple, limit: limit);
  }

  List<TeamNewsModel> _parseRssItems(
    String xml,
    String teamSymple, {
    required int limit,
  }) {
    final itemRegex = RegExp(r'<item>([\s\S]*?)<\/item>');
    final items = <TeamNewsModel>[];
    final seenTitles = <String>{};

    for (final match in itemRegex.allMatches(xml)) {
      final block = match.group(1) ?? '';
      final rawTitle = _extractTag(block, 'title');
      final link = _extractTag(block, 'link');
      final pubDateRaw = _extractTag(block, 'pubDate');
      final sourceTag = _extractTag(block, 'source');

      if (rawTitle.isEmpty || link.isEmpty) continue;

      final cleanRawTitle = _unescapeXml(rawTitle).trim();
      String title = cleanRawTitle;
      String source = _unescapeXml(sourceTag).trim();

      // Google News RSS 제목은 보통 "기사 제목 - 언론사" 형식
      final dashIndex = cleanRawTitle.lastIndexOf(' - ');
      if (dashIndex > 0) {
        title = cleanRawTitle.substring(0, dashIndex).trim();
        if (source.isEmpty) {
          source = cleanRawTitle.substring(dashIndex + 3).trim();
        }
      }
      if (source.isEmpty) source = '야구 뉴스';

      final dedupKey = title.replaceAll(RegExp(r'\s+'), '');
      if (dedupKey.isEmpty || !seenTitles.add(dedupKey)) continue;

      final publishedAt = _parseRfc822Date(pubDateRaw) ?? DateTime.now();

      items.add(
        TeamNewsModel(
          id: '${link.hashCode}_${publishedAt.millisecondsSinceEpoch}',
          teamSymple: teamSymple,
          title: title,
          source: source,
          url: link.trim(),
          publishedAt: publishedAt,
          category: TeamNewsModel.classifyTitle(title),
        ),
      );

      if (items.length >= limit) break;
    }

    items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return items;
  }

  String _extractTag(String block, String tag) {
    final regex = RegExp(
      '<$tag(?:\\s+[^>]*)?>([\\s\\S]*?)<\\/$tag>',
      caseSensitive: false,
    );
    final match = regex.firstMatch(block);
    if (match == null) return '';
    var value = (match.group(1) ?? '').trim();
    if (value.startsWith('<![CDATA[') && value.endsWith(']]>')) {
      value = value.substring(9, value.length - 3);
    }
    return value;
  }

  String _unescapeXml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  DateTime? _parseRfc822Date(String raw) {
    if (raw.isEmpty) return null;
    try {
      return HttpDate.parse(raw).toLocal();
    } catch (_) {
      return DateTime.tryParse(raw)?.toLocal();
    }
  }
}
