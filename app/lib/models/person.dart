import 'package:flutter/material.dart';

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.age,
    required this.initials,
    required this.avatarTint,
    required this.avatarInk,
    required this.distanceMeters,
    required this.reputationLine,
    required this.tags,
    this.reachable = true,
  });

  final String id;
  final String name;
  final int age;
  final String initials;
  final Color avatarTint;
  final Color avatarInk;
  final int distanceMeters;
  final String reputationLine;
  final List<String> tags;
  final bool reachable;

  String get distanceLabel => '$distanceMeters m';
}
