enum ReachabilityCategory {
  localQuestions('Local questions'),
  recommendations('Recommendations'),
  travel('Travel'),
  technology('Technology'),
  professionalAdvice('Professional advice'),
  study('Study'),
  hobbies('Hobbies'),
  helpingSomeone('Helping someone'),
  conversation('Conversation'),
  makingFriends('Making friends'),
  datingMeetingSomeone('Dating / Meeting someone');

  const ReachabilityCategory(this.label);

  final String label;
}

enum ReachableDuration {
  thirtyMinutes(Duration(minutes: 30), '30 min'),
  oneHour(Duration(hours: 1), '1 hr'),
  twoHours(Duration(hours: 2), '2 hrs');

  const ReachableDuration(this.duration, this.label);

  final Duration duration;
  final String label;
}
