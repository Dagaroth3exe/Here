/// The fixed set of things a Reachable user can say they're open to being
/// approached about. Keys must match the backend's REACHABILITY_CATEGORIES
/// exactly — labels are English source text, run through `t()` at display
/// time like every other UI string.
class ReachabilityCategory {
  const ReachabilityCategory(this.key, this.label);

  final String key;
  final String label;
}

const reachabilityCategories = [
  ReachabilityCategory('local_questions', 'Local questions'),
  ReachabilityCategory('recommendations', 'Recommendations'),
  ReachabilityCategory('travel', 'Travel'),
  ReachabilityCategory('technology', 'Technology'),
  ReachabilityCategory('professional_advice', 'Professional advice'),
  ReachabilityCategory('study', 'Study'),
  ReachabilityCategory('hobbies', 'Hobbies'),
  ReachabilityCategory('helping', 'Helping someone'),
  ReachabilityCategory('conversation', 'Conversation'),
  ReachabilityCategory('friends', 'Making friends'),
  ReachabilityCategory('dating', 'Dating / Meeting someone'),
];

String labelForCategory(String key) =>
    reachabilityCategories.firstWhere((c) => c.key == key, orElse: () => ReachabilityCategory(key, key)).label;
