import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';

class FeedHashtagEditor extends StatefulWidget {
  final List<String> tags;
  final Color accentColor;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onToggleQuickTag;
  final int maxTags;

  const FeedHashtagEditor({
    super.key,
    required this.tags,
    required this.accentColor,
    required this.onAdd,
    required this.onRemove,
    required this.onToggleQuickTag,
    this.maxTags = 10,
  });

  static const List<String> recommendedTags = [
    '직관인증',
    '승요',
    '오늘의경기',
    '잠실야구장',
    '좌석시야',
    '야구일상',
  ];

  @override
  State<FeedHashtagEditor> createState() => _FeedHashtagEditorState();
}

class _FeedHashtagEditorState extends State<FeedHashtagEditor> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submitTag() {
    final cleaned = _ctrl.text
        .trim()
        .replaceFirst(RegExp(r'^#+'), '')
        .replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return;
    widget.onAdd(cleaned);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTextColor =
        ThemeData.estimateBrightnessForColor(widget.accentColor) ==
            Brightness.dark
        ? WHITE
        : Colors.black;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '해시태그',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              Text(
                '${widget.tags.length} / ${widget.maxTags}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: TextStyle(fontSize: 13.5, color: context.textPrimary),
                  cursorColor: widget.accentColor,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitTag(),
                  decoration: InputDecoration(
                    hintText: '# 없이 태그 입력 (예: 직관인증)',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: context.textMuted,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: context.surfaceAltColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: widget.accentColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _submitTag,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: selectedTextColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '추가',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (widget.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.tags.map((tag) {
                return GestureDetector(
                  onTap: () => widget.onRemove(tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.close,
                          size: 13,
                          color: widget.accentColor,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: FeedHashtagEditor.recommendedTags.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final rec = FeedHashtagEditor.recommendedTags[idx];
                final exists = widget.tags.contains(rec);
                return GestureDetector(
                  onTap: () => widget.onToggleQuickTag(rec),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: exists
                          ? widget.accentColor.withValues(alpha: 0.14)
                          : context.surfaceAltColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: exists ? widget.accentColor : context.borderColor,
                      ),
                    ),
                    child: Text(
                      exists ? '#$rec ✓' : '+ #$rec',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: exists
                            ? widget.accentColor
                            : context.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FeedHashtagChips extends StatelessWidget {
  final List<String> hashtags;
  final Color accentColor;
  final ValueChanged<String>? onTapTag;

  const FeedHashtagChips({
    super.key,
    required this.hashtags,
    required this.accentColor,
    this.onTapTag,
  });

  @override
  Widget build(BuildContext context) {
    if (hashtags.isEmpty) return const SizedBox.shrink();
    final isDark = context.isDarkMode;
    final readableAccent = context.readableColor(accentColor);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: hashtags.map((tag) {
        final chip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: readableAccent.withValues(alpha: isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: readableAccent.withValues(alpha: isDark ? 0.36 : 0.24),
            ),
          ),
          child: Text(
            '#$tag',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: readableAccent,
              height: 1.25,
            ),
          ),
        );

        if (onTapTag == null) return chip;
        return GestureDetector(
          onTap: () => onTapTag!(tag),
          child: chip,
        );
      }).toList(),
    );
  }
}
