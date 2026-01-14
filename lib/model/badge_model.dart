import 'package:flutter/widgets.dart';

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool isLocked;
  final bool isViewed;
  final DateTime? acquiredAt;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.isLocked = true,
    this.isViewed = true,
    this.acquiredAt,
  });

  BadgeModel copyWith({bool? isLocked, bool? isViewed, DateTime? acquiredAt}) {
    return BadgeModel(
      id: id,
      name: name,
      description: description,
      icon: icon,
      isLocked: isLocked ?? this.isLocked,
      isViewed: isViewed ?? this.isViewed,
      acquiredAt: acquiredAt ?? this.acquiredAt,
    );
  }
}
