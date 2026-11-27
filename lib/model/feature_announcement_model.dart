import 'package:cloud_firestore/cloud_firestore.dart';

class FeatureMediaItem {
  final String type; // 'image' | 'video'
  final String url;
  final String caption;

  const FeatureMediaItem({
    required this.type,
    required this.url,
    this.caption = '',
  });

  bool get isVideo => type == 'video';

  factory FeatureMediaItem.fromMap(Map<String, dynamic> map) {
    return FeatureMediaItem(
      type: (map['type'] ?? 'image').toString(),
      url: (map['url'] ?? '').toString(),
      caption: (map['caption'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'type': type, 'url': url, 'caption': caption};
  }
}

class FeatureAnnouncementItem {
  final String id;
  final String tabLabel;
  final String title;
  final String ctaLabel;
  final String ctaTarget;
  final List<FeatureMediaItem> mediaItems;

  const FeatureAnnouncementItem({
    required this.id,
    required this.tabLabel,
    required this.title,
    this.ctaLabel = '',
    this.ctaTarget = '',
    required this.mediaItems,
  });

  factory FeatureAnnouncementItem.fromMap(Map<String, dynamic> map) {
    final rawMedia = map['mediaItems'] as List<dynamic>? ?? const [];
    return FeatureAnnouncementItem(
      id: (map['id'] ?? '').toString(),
      tabLabel: (map['tabLabel'] ?? map['title'] ?? '기능').toString(),
      title: (map['title'] ?? '').toString(),
      ctaLabel: (map['ctaLabel'] ?? '').toString(),
      ctaTarget: (map['ctaTarget'] ?? '').toString(),
      mediaItems: rawMedia
          .whereType<Map<String, dynamic>>()
          .map(FeatureMediaItem.fromMap)
          .where((item) => item.url.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tabLabel': tabLabel,
      'title': title,
      'ctaLabel': ctaLabel,
      'ctaTarget': ctaTarget,
      'mediaItems': mediaItems.map((e) => e.toMap()).toList(),
    };
  }
}

class FeatureAnnouncementModel {
  final String id;
  final bool isActive;
  final int priority;
  final String badge;
  final String title;
  final String targetVersion;
  final String updateMessage;
  final List<FeatureAnnouncementItem> features;
  final DateTime? createdAt;

  const FeatureAnnouncementModel({
    required this.id,
    required this.isActive,
    required this.priority,
    required this.badge,
    required this.title,
    this.targetVersion = '',
    this.updateMessage = '',
    required this.features,
    this.createdAt,
  });

  /// 두 버전 문자열(예: '1.3.0', '1.4.0')을 비교 (v1 < v2 이면 -1, 같으면 0, v1 > v2 이면 1)
  static int compareVersions(String v1, String v2) {
    List<int> parse(String v) {
      final clean = v
          .trim()
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split('+')
          .first;
      return clean
          .split('.')
          .map(
            (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
          )
          .toList();
    }

    final a = parse(v1);
    final b = parse(v2);
    final maxLen = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < maxLen; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av < bv) return -1;
      if (av > bv) return 1;
    }
    return 0;
  }

  /// 현재 앱 버전이 공지 대상 버전보다 낮아 스토어 업데이트가 필요한지 여부
  bool needsAppUpdate(String currentVersion) {
    if (targetVersion.trim().isEmpty || currentVersion.trim().isEmpty) {
      return false;
    }
    return compareVersions(currentVersion, targetVersion) < 0;
  }

  factory FeatureAnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawFeatures = data['features'] as List<dynamic>? ?? const [];
    var parsedFeatures = rawFeatures
        .whereType<Map<String, dynamic>>()
        .map(FeatureAnnouncementItem.fromMap)
        .where(
          (f) =>
              f.mediaItems.isNotEmpty ||
              f.title.trim().isNotEmpty ||
              f.tabLabel.trim().isNotEmpty,
        )
        .toList();

    // 하위 호환: 단일 기능으로 top-level mediaItems만 있는 경우
    if (parsedFeatures.isEmpty && data['mediaItems'] is List) {
      final legacyMedia = (data['mediaItems'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(FeatureMediaItem.fromMap)
          .where((m) => m.url.isNotEmpty)
          .toList();
      if (legacyMedia.isNotEmpty) {
        parsedFeatures = [
          FeatureAnnouncementItem(
            id: doc.id,
            tabLabel: (data['title'] ?? '새 기능').toString(),
            title: (data['title'] ?? '').toString(),
            ctaLabel: (data['ctaLabel'] ?? '').toString(),
            ctaTarget: (data['ctaTarget'] ?? '').toString(),
            mediaItems: legacyMedia,
          ),
        ];
      }
    }

    final ts = data['createdAt'];
    return FeatureAnnouncementModel(
      id: doc.id,
      isActive: data['isActive'] == true,
      priority: (data['priority'] as num?)?.toInt() ?? 0,
      badge: (data['badge'] ?? 'NEW FEATURE').toString(),
      title: (data['title'] ?? '새로운 기능 안내').toString(),
      targetVersion: (data['targetVersion'] ?? '').toString().trim(),
      updateMessage: (data['updateMessage'] ?? '').toString().trim(),
      features: parsedFeatures,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
