import 'package:flutter/material.dart';
import '../models/person.dart';

/// Seed data matching the handoff's Discover mock exactly.
final List<Person> seedPeople = [
  const Person(
    id: 'rahul-k',
    name: 'Rahul K.',
    age: 31,
    initials: 'RK',
    avatarTint: Color(0xFFE4EFE6),
    avatarInk: Color(0xFF3E6B4E),
    distanceMeters: 120,
    reputationLine: 'Helped 41 people · Trusted Helper',
    tags: ['Local questions', 'Rentals', 'Tech'],
  ),
  const Person(
    id: 'sneha-m',
    name: 'Sneha M.',
    age: 26,
    initials: 'SM',
    avatarTint: Color(0xFFF0E9DC),
    avatarInk: Color(0xFF7A6A4E),
    distanceMeters: 340,
    reputationLine: 'Helped 12 people · Lives here 6 yrs',
    tags: ['Recommendations', 'Study', 'Conversation'],
  ),
  const Person(
    id: 'arjun-v',
    name: 'Arjun V.',
    age: 38,
    initials: 'AV',
    avatarTint: Color(0xFFE6E9F0),
    avatarInk: Color(0xFF4E5A7A),
    distanceMeters: 450,
    reputationLine: 'Helped 76 people · Trusted Helper',
    tags: ['Professional advice', 'Tech', 'Travel'],
  ),
  const Person(
    id: 'priya-d',
    name: 'Priya D.',
    age: 24,
    initials: 'PD',
    avatarTint: Color(0xFFF0E4E6),
    avatarInk: Color(0xFF7A4E56),
    distanceMeters: 610,
    reputationLine: 'Helped 8 people · New nearby',
    tags: ['Making friends', 'Conversation'],
  ),
];
