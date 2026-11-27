import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/feature_announcement_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/feature_announcement_service.dart';
import 'package:lockerroom/widgets/feature_announcement_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class FeatureAnnouncementAdminPage extends StatefulWidget {
  const FeatureAnnouncementAdminPage({super.key});

  @override
  State<FeatureAnnouncementAdminPage> createState() =>
      _FeatureAnnouncementAdminPageState();
}

class _FeatureAnnouncementAdminPageState
    extends State<FeatureAnnouncementAdminPage> {
  final FeatureAnnouncementService _service = FeatureAnnouncementService();
  late Future<List<FeatureAnnouncementModel>> _listFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _listFuture = _service.fetchAllAnnouncements();
    });
  }

  Future<void> _openCreatePage() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const _FeatureAnnouncementCreatePage(),
      ),
    );
    if (created == true) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final accentColor = context.readableColor(teamColor);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          '신규 기능 안내 관리',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openCreatePage,
            tooltip: '새 안내 등록',
            icon: Icon(Icons.add_circle_outline, color: accentColor),
          ),
        ],
      ),
      body: FutureBuilder<List<FeatureAnnouncementModel>>(
        future: _listFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }
          final list = snapshot.data ?? const [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 48,
                    color: context.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '등록된 신규 기능 안내가 없습니다.',
                    style: TextStyle(color: context.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openCreatePage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: WHITE,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('새 기능 안내 만들기'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = list[index];
              final totalMedia = item.features.fold<int>(
                0,
                (sum, f) => sum + f.mediaItems.length,
              );
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                        if (item.targetVersion.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.surfaceAltColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'v${item.targetVersion}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Switch(
                          value: item.isActive,
                          activeThumbColor: accentColor,
                          onChanged: (val) async {
                            await _service.toggleActive(item.id, val);
                            _reload();
                          },
                        ),
                      ],
                    ),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '기능 ${item.features.length}개 · 미디어 $totalMedia개 · 우선순위 ${item.priority}',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            FeatureAnnouncementDialog.show(
                              context,
                              announcement: item,
                            );
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('미리보기'),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: () async {
                            final updated = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    _FeatureAnnouncementCreatePage(
                                      existing: item,
                                    ),
                              ),
                            );
                            if (updated == true) _reload();
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('수정'),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: () async {
                            await _service.deleteAnnouncement(item.id);
                            _reload();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('삭제'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DraftMedia {
  final File? file;
  final String? remoteUrl;
  final bool isVideo;
  final TextEditingController captionCtrl = TextEditingController();

  _DraftMedia({
    this.file,
    this.remoteUrl,
    required this.isVideo,
    String initialCaption = '',
  }) {
    captionCtrl.text = initialCaption;
  }

  void dispose() => captionCtrl.dispose();
}

class _DraftFeature {
  final TextEditingController tabLabelCtrl = TextEditingController();
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController ctaLabelCtrl = TextEditingController();
  String ctaTarget = '';
  final List<_DraftMedia> media = [];

  void dispose() {
    tabLabelCtrl.dispose();
    titleCtrl.dispose();
    ctaLabelCtrl.dispose();
    for (final m in media) {
      m.dispose();
    }
  }
}

class _FeatureAnnouncementCreatePage extends StatefulWidget {
  final FeatureAnnouncementModel? existing;
  const _FeatureAnnouncementCreatePage({this.existing});

  @override
  State<_FeatureAnnouncementCreatePage> createState() =>
      _FeatureAnnouncementCreatePageState();
}

class _FeatureAnnouncementCreatePageState
    extends State<_FeatureAnnouncementCreatePage> {
  final _service = FeatureAnnouncementService();
  final _picker = ImagePicker();
  final _badgeCtrl = TextEditingController(text: 'UPDATE');
  final _titleCtrl = TextEditingController();
  final _targetVersionCtrl = TextEditingController();
  final _updateMessageCtrl = TextEditingController();
  final _priorityCtrl = TextEditingController(text: '100');
  final List<_DraftFeature> _features = [];
  bool _isActive = true;
  bool _isUploading = false;
  String _currentAppVersion = '';

  bool get _isEditMode => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _badgeCtrl.text = ex.badge;
      _titleCtrl.text = ex.title;
      _targetVersionCtrl.text = ex.targetVersion;
      _updateMessageCtrl.text = ex.updateMessage;
      _priorityCtrl.text = '${ex.priority}';
      _isActive = ex.isActive;
      for (final f in ex.features) {
        final draft = _DraftFeature();
        draft.tabLabelCtrl.text = f.tabLabel;
        draft.titleCtrl.text = f.title;
        draft.ctaLabelCtrl.text = f.ctaLabel;
        draft.ctaTarget = f.ctaTarget;
        for (final m in f.mediaItems) {
          draft.media.add(
            _DraftMedia(
              remoteUrl: m.url,
              isVideo: m.isVideo,
              initialCaption: m.caption,
            ),
          );
        }
        _features.add(draft);
      }
    }
    if (_features.isEmpty) {
      _features.add(_DraftFeature());
    }
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _currentAppVersion = info.version);
    });
  }

  static const _ctaTargets = <MapEntry<String, String>>[
    MapEntry('', '이동 없음 (확인 버튼)'),
    MapEntry('ticket_scan', '스마트 티켓 스캔'),
    MapEntry('intuition_record', '나의 직관기록'),
    MapEntry('quiz', '야잘알 퀴즈'),
    MapEntry('meetup', '직관 모임'),
    MapEntry('schedule', '경기 일정'),
  ];

  @override
  void dispose() {
    _badgeCtrl.dispose();
    _titleCtrl.dispose();
    _targetVersionCtrl.dispose();
    _updateMessageCtrl.dispose();
    _priorityCtrl.dispose();
    for (final f in _features) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages(_DraftFeature feature) async {
    final files = await _picker.pickMultiImage(imageQuality: 88);
    if (files.isEmpty) return;
    setState(() {
      for (final x in files) {
        feature.media.add(_DraftMedia(file: File(x.path), isVideo: false));
      }
    });
  }

  Future<void> _pickVideo(_DraftFeature feature) async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      feature.media.add(_DraftMedia(file: File(file.path), isVideo: true));
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공지 제목을 입력해 주세요.')),
      );
      return;
    }

    final targetVersion = _targetVersionCtrl.text.trim();
    final updateMessage = _updateMessageCtrl.text.trim();
    final isUpdateOnlyNotice =
        targetVersion.isNotEmpty &&
        _features.every((f) => f.media.isEmpty);

    if (!isUpdateOnlyNotice) {
      for (final f in _features) {
        if (f.media.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '각 기능에 사진/동영상을 추가하거나, 구버전 업데이트 전용 공지라면 대상 앱 버전을 입력해 주세요.',
              ),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isUploading = true);
    try {
      final docId =
          widget.existing?.id ??
          'feat_${DateTime.now().millisecondsSinceEpoch}';
      final builtFeatures = <FeatureAnnouncementItem>[];

      for (var i = 0; i < _features.length; i++) {
        final f = _features[i];
        final hasText =
            f.titleCtrl.text.trim().isNotEmpty ||
            f.tabLabelCtrl.text.trim().isNotEmpty;
        if (f.media.isEmpty && !hasText) continue;

        final uploadedMedia = <FeatureMediaItem>[];
        for (final m in f.media) {
          final String url;
          if (m.remoteUrl != null && m.remoteUrl!.isNotEmpty) {
            url = m.remoteUrl!;
          } else if (m.file != null) {
            url = await _service.uploadMediaFile(
              m.file!,
              docId,
              isVideo: m.isVideo,
            );
          } else {
            continue;
          }
          uploadedMedia.add(
            FeatureMediaItem(
              type: m.isVideo ? 'video' : 'image',
              url: url,
              caption: m.captionCtrl.text.trim(),
            ),
          );
        }

        final fTitle = f.titleCtrl.text.trim().isNotEmpty
            ? f.titleCtrl.text.trim()
            : title;
        final tabLabel = f.tabLabelCtrl.text.trim().isNotEmpty
            ? f.tabLabelCtrl.text.trim()
            : fTitle;

        builtFeatures.add(
          FeatureAnnouncementItem(
            id: 'f_$i',
            tabLabel: tabLabel,
            title: fTitle,
            ctaLabel: f.ctaLabelCtrl.text.trim(),
            ctaTarget: f.ctaTarget,
            mediaItems: uploadedMedia,
          ),
        );
      }

      final badgeText = _badgeCtrl.text.trim().isNotEmpty
          ? _badgeCtrl.text.trim()
          : 'NEW FEATURE';
      final priorityVal = int.tryParse(_priorityCtrl.text.trim()) ?? 100;

      if (_isEditMode) {
        await _service.updateAnnouncement(
          docId: docId,
          badge: badgeText,
          title: title,
          priority: priorityVal,
          isActive: _isActive,
          targetVersion: targetVersion,
          updateMessage: updateMessage,
          features: builtFeatures,
        );
      } else {
        await _service.createAnnouncement(
          docId: docId,
          badge: badgeText,
          title: title,
          priority: priorityVal,
          isActive: _isActive,
          targetVersion: targetVersion,
          updateMessage: updateMessage,
          features: builtFeatures,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final accentColor = context.readableColor(teamColor);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          _isEditMode ? '새 기능 안내 수정' : '새 기능 안내 등록',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _submit,
            child: _isUploading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  )
                : Text(
                    _isEditMode ? '저장' : '등록',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '기본 공지 정보',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _badgeCtrl,
                  decoration: const InputDecoration(
                    labelText: '상단 배지 (예: UPDATE v2.4)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '전체 공지 제목 (예: 새로워진 iLU를 만나보세요!)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _targetVersionCtrl,
                  decoration: InputDecoration(
                    labelText: '대상 앱 버전 (예: 1.4.4 · 비우면 모든 버전에 기능 안내)',
                    helperText: _currentAppVersion.isNotEmpty
                        ? '현재 기기 앱 버전: v$_currentAppVersion (입력 버전 이상: 기능 안내 / 미만: 업데이트 유도)'
                        : null,
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _updateMessageCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '구버전 유저 안내 문구 (선택 · 비우면 기본 업데이트 문구 사용)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priorityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '우선순위 (높을수록 먼저 노출)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        Text(
                          '즉시 노출',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                        Switch(
                          value: _isActive,
                          activeThumbColor: accentColor,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_features.length, (idx) {
            final f = _features[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildSectionCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '기능 ${idx + 1}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        if (_features.length > 1)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                final removed = _features.removeAt(idx);
                                removed.dispose();
                              });
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: f.tabLabelCtrl,
                      decoration: const InputDecoration(
                        labelText: '탭 이름 (기능이 2개 이상일 때 표시)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: f.titleCtrl,
                      decoration: const InputDecoration(
                        labelText: '기능 소제목 (예: 지류 티켓 자동 스캔)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: f.ctaLabelCtrl,
                      decoration: const InputDecoration(
                        labelText: '버튼 문구 (예: 지금 스캔하기)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: f.ctaTarget,
                      decoration: const InputDecoration(
                        labelText: '버튼 클릭 시 이동 화면',
                        border: OutlineInputBorder(),
                      ),
                      items: _ctaTargets
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => f.ctaTarget = v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImages(f),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('사진 여러 장 추가'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickVideo(f),
                            icon: const Icon(Icons.videocam_outlined),
                            label: const Text('동영상 추가'),
                          ),
                        ),
                      ],
                    ),
                    if (f.media.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...List.generate(f.media.length, (mIdx) {
                        final m = f.media[mIdx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.surfaceAltColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: m.isVideo
                                    ? Container(
                                        width: 56,
                                        height: 56,
                                        color: Colors.black87,
                                        child: const Icon(
                                          Icons.videocam,
                                          color: WHITE,
                                        ),
                                      )
                                    : (m.remoteUrl != null &&
                                          m.remoteUrl!.isNotEmpty)
                                    ? Image.network(
                                        m.remoteUrl!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        m.file!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              const SizedBox(width: 10),
                                Expanded(
                                child: TextField(
                                  controller: m.captionCtrl,
                                  minLines: 1,
                                  maxLines: 4,
                                  keyboardType: TextInputType.multiline,
                                  decoration: InputDecoration(
                                    hintText: m.isVideo
                                        ? '동영상 설명(캡션 · 엔터로 줄바꿈 가능)'
                                        : '사진 ${mIdx + 1} 설명(캡션 · 엔터로 줄바꿈 가능)',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    final removed = f.media.removeAt(mIdx);
                                    removed.dispose();
                                  });
                                },
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => setState(() => _features.add(_DraftFeature())),
            icon: const Icon(Icons.add),
            label: const Text('다른 신규 기능 추가하기'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: child,
    );
  }
}
