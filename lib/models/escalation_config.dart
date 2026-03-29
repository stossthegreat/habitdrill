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
      'You missed {habit}. The Sergeant is waiting.',
      'Still haven\'t opened the app? Get in here.',
      'This is your second warning. Open Drillsarj NOW.',
      'I\'ve been waiting. Your punishment is getting worse.',
      'LAST CHANCE. Open the app or tomorrow will be hell.',
    ],
    2: [
      'You missed {habit} AGAIN. The Sergeant is NOT happy.',
      'Drop what you\'re doing and open Drillsarj. NOW.',
      'You think you can hide? Get in here, recruit!',
      'Your punishment just doubled. Open the app.',
      'I will NOT forget this. Get in here immediately.',
    ],
    3: [
      '{habit} BROKEN AGAIN?! GET IN THE APP RIGHT NOW!',
      'THIS IS UNACCEPTABLE! OPEN DRILLSARJ IMMEDIATELY!',
      'YOU ARE IN SERIOUS TROUBLE! GET IN HERE!',
      'YOUR PUNISHMENT IS THROUGH THE ROOF! OPEN NOW!',
      'I HAVE BEEN WAITING ALL DAY! GET IN HERE SOLDIER!',
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
