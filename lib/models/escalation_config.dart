class EscalationConfig {
  // Video assets per escalation level
  static const Map<int, String> videoAssets = {
    1: 'assets/images/sergeant_level1.mp4',
    2: 'assets/images/sergeant_level2.mp4',
    3: 'assets/images/sergeant_level3.mp4',
  };

  // Special videos
  static const String temptedVideo = 'assets/images/sergeant_almost.mp4';
  static const String introVideo = 'assets/images/sergeant_intro.mp4';

  // Notification timing (minutes after violation detected)
  static const List<int> notificationDelayMinutes = [0, 15, 45, 120, 360];

  // Notification messages per escalation level
  static const Map<int, List<String>> notificationMessages = {
    1: [
      'ORDER FAILED: {habit}. Open Drillsarj.',
      '{habit} not completed. Punishment waiting.',
      'Second warning. {habit} still failed.',
      'Your punishment is escalating. Open now.',
      'Final warning. {habit}.',
    ],
    2: [
      'ORDER FAILED AGAIN: {habit}. Strike 2.',
      '{habit} failed twice. Open Drillsarj. NOW.',
      'Strike 2. Punishment doubled.',
      'Still hiding? {habit} still failed.',
      'This will not be forgotten. Open the app.',
    ],
    3: [
      'STRIKE 3: {habit}. OPEN NOW.',
      '{habit} FAILED AGAIN. MAXIMUM PUNISHMENT.',
      'YOU KEEP FAILING. OPEN DRILLSARJ.',
      'PUNISHMENT AT MAXIMUM. OPEN NOW.',
      'LAST WARNING. {habit}.',
    ],
  };

  // Max rep multiplier
  static const int maxRepMultiplier = 5;

  // Get notification message for a violation
  static String getMessage(int level, int notificationIndex, String habitTitle) {
    final messages = notificationMessages[level.clamp(1, 3)]!;
    final idx = notificationIndex.clamp(0, messages.length - 1);
    return messages[idx].replaceAll('{habit}', habitTitle);
  }
}
