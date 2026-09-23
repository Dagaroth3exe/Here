/// Up to two uppercase initials for an avatar, from a display name.
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final part = parts.first;
    return (part.length >= 2 ? part.substring(0, 2) : part).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
