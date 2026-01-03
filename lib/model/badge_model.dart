import 'package:flutter/widgets.dart';

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool isLocked;
  final DateTime? acquiredAt;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.isLocked = true,
    this.acquiredAt,
  });

  BadgeModel copyWith({bool? isLocked, DateTime? acquiredAt}) {
    return BadgeModel(
      id: id,
      name: name,
      description: description,
      icon: icon,
      isLocked: isLocked ?? this.isLocked,
      acquiredAt: acquiredAt ?? this.acquiredAt,
    );
  }
}
