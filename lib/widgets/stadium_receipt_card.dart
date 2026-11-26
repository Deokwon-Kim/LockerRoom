import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/widgets/ilu_share_card.dart';

/// 구장 먹거리 원탭 선택 태그 목록
const List<({String emoji, String label})> kStadiumFoodTags = [
  (emoji: '🍗', label: '치킨'),
  (emoji: '🍺', label: '맥주'),
  (emoji: '🍢', label: '떡볶이'),
  (emoji: '🌭', label: '핫도그'),
  (emoji: '🥤', label: '음료'),
  (emoji: '🍱', label: '도시락'),
];

/// 유니폼 · 굿즈 · 포토카드 원탭 선택 태그 목록
const List<({String emoji, String label})> kStadiumGoodsTags = [
  (emoji: '👕', label: '유니폼'),
  (emoji: '🧸', label: '굿즈'),
  (emoji: '🃏', label: '포토카드'),
  (emoji: '🧢', label: '모자·잡화'),
  (emoji: '📣', label: '응원도구'),
  (emoji: '🔑', label: '키링·뱃지'),
];

/// 직관 티켓 비용 + 구장 먹거리 + 1승당 가성비를 영수증 형태로 보여주는 카드
class StadiumReceiptCard extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final int? selectedYear;
  final int wins;
  final int losses;

  const StadiumReceiptCard({
    super.key,
    required this.records,
    required this.selectedYear,
    required this.wins,
    required this.losses,
  });

  int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    int totalTicketCost = 0;
    int totalFoodCost = 0;
    int totalGoodsCost = 0;
    final Map<String, int> foodCounts = {};
    final Map<String, int> goodsCounts = {};
    final Map<String, ({int ticket, int food, int goods})> monthlyMap = {};

    for (final r in records) {
      final t = _parseInt(r['ticketPrice']);
      final f = _parseInt(r['foodCost']);
      final g = _parseInt(r['goodsCost']);
      totalTicketCost += t;
      totalFoodCost += f;
      totalGoodsCost += g;

      final rawDate = (r['date'] ?? '').toString();
      final parts = rawDate.split('.');
      if (parts.length >= 2 && (t + f + g) > 0) {
        final ymKey = '${parts[0]}.${parts[1].padLeft(2, '0')}';
        final prev = monthlyMap[ymKey] ?? (ticket: 0, food: 0, goods: 0);
        monthlyMap[ymKey] = (
          ticket: prev.ticket + t,
          food: prev.food + f,
          goods: prev.goods + g,
        );
      }

      final rawFoods = r['foodItems'];
      if (rawFoods is List) {
        for (final item in rawFoods) {
          final name = item.toString().trim();
          if (name.isNotEmpty) {
            foodCounts[name] = (foodCounts[name] ?? 0) + 1;
          }
        }
      }

      final rawGoods = r['goodsItems'];
      if (rawGoods is List) {
        for (final item in rawGoods) {
          final name = item.toString().trim();
          if (name.isNotEmpty) {
            goodsCounts[name] = (goodsCounts[name] ?? 0) + 1;
          }
        }
      }
    }

    final int totalCost = totalTicketCost + totalFoodCost + totalGoodsCost;
    final sortedFoods = foodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final String topFoodsText = sortedFoods.take(3).map((e) => e.key).join('·');
    final sortedGoods = goodsCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final String topGoodsText = sortedGoods.take(3).map((e) => e.key).join('·');

    final monthlyKeys = monthlyMap.keys.toList()..sort();
    final recentMonthlyKeys = monthlyKeys.length > 5
        ? monthlyKeys.sublist(monthlyKeys.length - 5)
        : monthlyKeys;

    final formatter = NumberFormat('#,###');
    final int costPerWin = wins > 0 ? (totalCost / wins).round() : 0;
    final String seasonLabel = selectedYear != null ? '$selectedYear 시즌' : '통산';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (totalCost > 0) ...[
          _ExpenseRatioChartCard(
            ticketCost: totalTicketCost,
            foodCost: totalFoodCost,
            goodsCost: totalGoodsCost,
            totalCost: totalCost,
            formatter: formatter,
          ),
          const SizedBox(height: 12),
        ],
        if (recentMonthlyKeys.isNotEmpty) ...[
          _MonthlyExpenseChartCard(
            recentMonthlyKeys: recentMonthlyKeys,
            monthlyMap: monthlyMap,
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: WHITE,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GRAYSCALE_LABEL_200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        'ILU STADIUM RECEIPT',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: GRAYSCALE_LABEL_950,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => showIluWatermarkShareSheet(
                            context: context,
                            watermarkSubtitle: '$seasonLabel 직관 가성비 영수증',
                            shareText:
                                '$seasonLabel 내 직관 가성비 영수증 🧾 #ILU #직관가성비',
                            shareContent: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'ILU STADIUM RECEIPT',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      color: GRAYSCALE_LABEL_950,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const _DashedDivider(),
                                  const SizedBox(height: 10),
                                  _ReceiptRow(
                                    label: '티켓 비용 (${records.length}경기)',
                                    amount:
                                        '${formatter.format(totalTicketCost)}원',
                                  ),
                                  const SizedBox(height: 6),
                                  _ReceiptRow(
                                    label: topFoodsText.isNotEmpty
                                        ? '구장 먹거리 ($topFoodsText)'
                                        : '구장 먹거리',
                                    amount:
                                        '${formatter.format(totalFoodCost)}원',
                                  ),
                                  const SizedBox(height: 6),
                                  _ReceiptRow(
                                    label: topGoodsText.isNotEmpty
                                        ? '유니폼·굿즈 ($topGoodsText)'
                                        : '유니폼·굿즈',
                                    amount:
                                        '${formatter.format(totalGoodsCost)}원',
                                  ),
                                  const SizedBox(height: 10),
                                  const _DashedDivider(),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        '총 직관 투자금',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: GRAYSCALE_LABEL_950,
                                        ),
                                      ),
                                      Text(
                                        '${formatter.format(totalCost)}원',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: GRAYSCALE_LABEL_950,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: BACKGROUND_COLOR,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '🏆 1승당 가성비 ($wins승 $losses패)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: GRAYSCALE_LABEL_900,
                                          ),
                                        ),
                                        Text(
                                          wins > 0
                                              ? '${formatter.format(costPerWin)}원 / 승'
                                              : '첫 승 대기 중!',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: ACCENT_CORAL,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.share,
                            size: 17,
                            color: GRAYSCALE_LABEL_600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$seasonLabel 직관 가성비 영수증',
                    style: const TextStyle(
                      fontSize: 12,
                      color: GRAYSCALE_LABEL_500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _DashedDivider(),
              const SizedBox(height: 12),
              _ReceiptRow(
                label: '티켓 비용 (${records.length}경기)',
                amount: '${formatter.format(totalTicketCost)}원',
              ),
              const SizedBox(height: 8),
              _ReceiptRow(
                label: topFoodsText.isNotEmpty
                    ? '구장 먹거리 ($topFoodsText)'
                    : '구장 먹거리',
                amount: '${formatter.format(totalFoodCost)}원',
              ),
              const SizedBox(height: 8),
              _ReceiptRow(
                label: topGoodsText.isNotEmpty
                    ? '유니폼·굿즈 ($topGoodsText)'
                    : '유니폼·굿즈',
                amount: '${formatter.format(totalGoodsCost)}원',
              ),
              const SizedBox(height: 12),
              const _DashedDivider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '총 직관 투자금',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: GRAYSCALE_LABEL_950,
                    ),
                  ),
                  Text(
                    '${formatter.format(totalCost)}원',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: GRAYSCALE_LABEL_950,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: BACKGROUND_COLOR,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GRAYSCALE_LABEL_200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🏆 1승당 가성비 ($wins승 $losses패)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GRAYSCALE_LABEL_900,
                      ),
                    ),
                    Text(
                      wins > 0
                          ? '${formatter.format(costPerWin)}원 / 승'
                          : '첫 승 대기 중!',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: ACCENT_CORAL,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String amount;

  const _ReceiptRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: GRAYSCALE_LABEL_600,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: GRAYSCALE_LABEL_950,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 8).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: 4, height: 1, color: GRAYSCALE_LABEL_300),
          ),
        );
      },
    );
  }
}

/// 구장 먹거리/굿즈 태그 선택 + 직접 추가 + 항목별 금액 입력 공용 위젯
class StadiumFoodSelector extends StatefulWidget {
  final List<String> selectedItems;
  final Map<String, int> itemPrices;
  final ValueChanged<String> onToggleItem;
  final ValueChanged<String> onAddCustomItem;
  final void Function(String item, int price) onItemPriceChanged;
  final TextEditingController costController;
  final List<({String emoji, String label})> tags;
  final String defaultEmoji;
  final String totalLabel;
  final String hintText;
  final IconData prefixIcon;

  const StadiumFoodSelector({
    super.key,
    required this.selectedItems,
    required this.itemPrices,
    required this.onToggleItem,
    required this.onAddCustomItem,
    required this.onItemPriceChanged,
    required this.costController,
    this.tags = kStadiumFoodTags,
    this.defaultEmoji = '🍽️',
    this.totalLabel = '구장 먹거리 합계',
    this.hintText = '위 칩을 누르거나 총 먹거리 금액 입력 (예: 24000)',
    this.prefixIcon = Icons.fastfood_outlined,
  });

  @override
  State<StadiumFoodSelector> createState() => _StadiumFoodSelectorState();
}

class _StadiumFoodSelectorState extends State<StadiumFoodSelector> {
  final Map<String, TextEditingController> _itemControllers = {};

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant StadiumFoodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    final currentSet = widget.selectedItems.toSet();
    final removedKeys = _itemControllers.keys
        .where((k) => !currentSet.contains(k))
        .toList();
    for (final key in removedKeys) {
      _itemControllers.remove(key)?.dispose();
    }
    for (final item in widget.selectedItems) {
      final ctrl = _itemControllers.putIfAbsent(item, () {
        final price = widget.itemPrices[item] ?? 0;
        return TextEditingController(text: price > 0 ? '$price' : '');
      });
      final expected = widget.itemPrices[item] ?? 0;
      if (ctrl.text.isEmpty && expected > 0) {
        ctrl.text = '$expected';
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _itemControllers.values) {
      ctrl.dispose();
    }
    _itemControllers.clear();
    super.dispose();
  }

  String _emojiFor(String item) {
    for (final tag in widget.tags) {
      if (tag.label == item) return tag.emoji;
    }
    return widget.defaultEmoji;
  }

  Future<void> _showAddCustomDialog(BuildContext context) async {
    final added = await showDialog<String>(
      context: context,
      builder: (_) => const _AddFoodDialog(),
    );
    if (added != null && added.isNotEmpty) {
      widget.onAddCustomItem(added);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultLabels = widget.tags.map((t) => t.label).toSet();
    final customItems = widget.selectedItems
        .where((item) => !defaultLabels.contains(item))
        .toList();
    final int sumFromItems = widget.selectedItems.fold<int>(
      0,
      (sum, item) => sum + (widget.itemPrices[item] ?? 0),
    );
    final int fallbackTotal =
        int.tryParse(widget.costController.text.replaceAll(',', '').trim()) ??
        0;
    final int displayTotal = sumFromItems > 0 ? sumFromItems : fallbackTotal;
    final formatter = NumberFormat('#,###');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...widget.tags.map((tag) {
              final selected = widget.selectedItems.contains(tag.label);
              return _FoodChip(
                label: '${tag.emoji} ${tag.label}',
                selected: selected,
                onTap: () => widget.onToggleItem(tag.label),
              );
            }),
            ...customItems.map(
              (item) => _FoodChip(
                label: '${widget.defaultEmoji} $item ×',
                selected: true,
                onTap: () => widget.onToggleItem(item),
              ),
            ),
            GestureDetector(
              onTap: () => _showAddCustomDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: BACKGROUND_COLOR,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GRAYSCALE_LABEL_300),
                ),
                child: const Text(
                  '+ 직접 추가',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BUTTON,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.selectedItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GRAYSCALE_LABEL_200),
            ),
            child: Column(
              children: [
                ...widget.selectedItems.map((item) {
                  final ctrl = _itemControllers[item]!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_emojiFor(item)} $item',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: GRAYSCALE_LABEL_900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 112,
                          child: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            cursorColor: BUTTON,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '금액',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: GRAYSCALE_LABEL_400,
                              ),
                              suffixText: '원',
                              suffixStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: GRAYSCALE_LABEL_600,
                              ),
                              filled: true,
                              fillColor: BACKGROUND_COLOR,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: GRAYSCALE_LABEL_200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: BUTTON,
                                  width: 1.3,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              final parsed =
                                  int.tryParse(
                                    val.replaceAll(',', '').trim(),
                                  ) ??
                                  0;
                              widget.onItemPriceChanged(item, parsed);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => widget.onToggleItem(item),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: GRAYSCALE_LABEL_400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 16, color: GRAYSCALE_LABEL_200),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.totalLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: GRAYSCALE_LABEL_700,
                      ),
                    ),
                    Text(
                      '${formatter.format(displayTotal)}원',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: ACCENT_CORAL,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          TextFormField(
            controller: widget.costController,
            keyboardType: TextInputType.number,
            cursorColor: BUTTON,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: GRAYSCALE_LABEL_400,
              ),
              suffixText: '원',
              suffixStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GRAYSCALE_LABEL_700,
              ),
              filled: true,
              fillColor: WHITE,
              prefixIcon: Icon(
                widget.prefixIcon,
                size: 20,
                color: GRAYSCALE_LABEL_500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: GRAYSCALE_LABEL_200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: BUTTON, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddFoodDialog extends StatefulWidget {
  const _AddFoodDialog();

  @override
  State<_AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<_AddFoodDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: WHITE,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '먹거리 직접 추가',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        cursorColor: BUTTON,
        decoration: InputDecoration(
          hintText: '예: 크림새우, 삼겹살정식, 츄러스',
          hintStyle: const TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_400),
          filled: true,
          fillColor: BACKGROUND_COLOR,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: GRAYSCALE_LABEL_200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: BUTTON, width: 1.5),
          ),
        ),
        onSubmitted: (val) => Navigator.pop(context, val.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(color: GRAYSCALE_LABEL_600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: BUTTON,
            foregroundColor: WHITE,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: const Text(
            '추가',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _FoodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FoodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? BUTTON : WHITE,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? BUTTON : GRAYSCALE_LABEL_200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? WHITE : GRAYSCALE_LABEL_800,
          ),
        ),
      ),
    );
  }
}

const Color _kExpenseTicketColor = Color(0xFF074CA1);
const Color _kExpenseFoodColor = Color(0xFFF59E0B);
const Color _kExpenseGoodsColor = Color(0xFFFF5A5F);

class _ExpenseRatioChartCard extends StatelessWidget {
  final int ticketCost;
  final int foodCost;
  final int goodsCost;
  final int totalCost;
  final NumberFormat formatter;

  const _ExpenseRatioChartCard({
    required this.ticketCost,
    required this.foodCost,
    required this.goodsCost,
    required this.totalCost,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final int pctTicket = totalCost > 0
        ? ((ticketCost / totalCost) * 100).round()
        : 0;
    final int pctFood = totalCost > 0
        ? ((foodCost / totalCost) * 100).round()
        : 0;
    final int pctGoods = totalCost > 0
        ? math.max(0, 100 - pctTicket - pctFood)
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GRAYSCALE_LABEL_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 직관 지출 비중 그래프',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: GRAYSCALE_LABEL_950,
                ),
              ),
              Text(
                '총 ${formatter.format(totalCost)}원',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: GRAYSCALE_LABEL_500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(108, 108),
                      painter: _ExpenseDonutPainter(
                        ticket: ticketCost,
                        food: foodCost,
                        goods: goodsCost,
                        ticketColor: _kExpenseTicketColor,
                        foodColor: _kExpenseFoodColor,
                        goodsColor: _kExpenseGoodsColor,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: GRAYSCALE_LABEL_500,
                          ),
                        ),
                        Text(
                          '${(totalCost / 10000).toStringAsFixed(1)}만원',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: GRAYSCALE_LABEL_950,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _LegendItem(
                      color: _kExpenseTicketColor,
                      label: '티켓',
                      amount: '${formatter.format(ticketCost)}원',
                      percent: pctTicket,
                    ),
                    const SizedBox(height: 8),
                    _LegendItem(
                      color: _kExpenseFoodColor,
                      label: '먹거리',
                      amount: '${formatter.format(foodCost)}원',
                      percent: pctFood,
                    ),
                    const SizedBox(height: 8),
                    _LegendItem(
                      color: _kExpenseGoodsColor,
                      label: '유니폼·굿즈',
                      amount: '${formatter.format(goodsCost)}원',
                      percent: pctGoods,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (ticketCost > 0)
                    Expanded(
                      flex: ticketCost,
                      child: Container(color: _kExpenseTicketColor),
                    ),
                  if (foodCost > 0)
                    Expanded(
                      flex: foodCost,
                      child: Container(color: _kExpenseFoodColor),
                    ),
                  if (goodsCost > 0)
                    Expanded(
                      flex: goodsCost,
                      child: Container(color: _kExpenseGoodsColor),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyExpenseChartCard extends StatelessWidget {
  final List<String> recentMonthlyKeys;
  final Map<String, ({int ticket, int food, int goods})> monthlyMap;

  const _MonthlyExpenseChartCard({
    required this.recentMonthlyKeys,
    required this.monthlyMap,
  });

  @override
  Widget build(BuildContext context) {
    final int maxMonthTotal = recentMonthlyKeys.fold<int>(1, (maxVal, key) {
      final m = monthlyMap[key]!;
      final total = m.ticket + m.food + m.goods;
      return total > maxVal ? total : maxVal;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GRAYSCALE_LABEL_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📅 월별 직관 지출 추이',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: GRAYSCALE_LABEL_950,
                ),
              ),
              Text(
                '티켓 + 먹거리 + 굿즈',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: GRAYSCALE_LABEL_500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: recentMonthlyKeys.map((key) {
                final m = monthlyMap[key]!;
                final total = m.ticket + m.food + m.goods;
                final double barH = (total / maxMonthTotal * 64).clamp(
                  10.0,
                  64.0,
                );
                final double hT = total > 0 ? (m.ticket / total) * barH : 0;
                final double hF = total > 0 ? (m.food / total) * barH : 0;
                final double hG = math.max(0, barH - hT - hF);
                final monthNum = int.tryParse(key.split('.').last) ?? 0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${(total / 10000).toStringAsFixed(1)}만',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: GRAYSCALE_LABEL_500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                        bottom: Radius.circular(4),
                      ),
                      child: SizedBox(
                        width: 24,
                        height: barH,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (hG > 0)
                              Container(height: hG, color: _kExpenseGoodsColor),
                            if (hF > 0)
                              Container(height: hF, color: _kExpenseFoodColor),
                            if (hT > 0)
                              Container(
                                height: hT,
                                color: _kExpenseTicketColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      monthNum > 0 ? '$monthNum월' : key,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: GRAYSCALE_LABEL_700,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String amount;
  final int percent;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.amount,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: GRAYSCALE_LABEL_700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: GRAYSCALE_LABEL_950,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$percent%',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: GRAYSCALE_LABEL_500,
          ),
        ),
      ],
    );
  }
}

class _ExpenseDonutPainter extends CustomPainter {
  final int ticket;
  final int food;
  final int goods;
  final Color ticketColor;
  final Color foodColor;
  final Color goodsColor;

  _ExpenseDonutPainter({
    required this.ticket,
    required this.food,
    required this.goods,
    required this.ticketColor,
    required this.foodColor,
    required this.goodsColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = ticket + food + goods;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 8,
    );
    const strokeWidth = 12.0;

    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = GRAYSCALE_LABEL_200
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      return;
    }

    double startAngle = -math.pi / 2;
    void drawSlice(int value, Color color) {
      if (value <= 0) return;
      final sweep = (value / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }

    drawSlice(ticket, ticketColor);
    drawSlice(food, foodColor);
    drawSlice(goods, goodsColor);
  }

  @override
  bool shouldRepaint(covariant _ExpenseDonutPainter oldDelegate) =>
      oldDelegate.ticket != ticket ||
      oldDelegate.food != food ||
      oldDelegate.goods != goods;
}
