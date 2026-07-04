// This class handles the Spaced Repetition Math.
// You can call this whenever a user swipes a card.

class SM2Response {
  final int interval;
  final int repetitions;
  final double easeFactor;
  final DateTime nextReviewDate;

  SM2Response({
    required this.interval,
    required this.repetitions,
    required this.easeFactor,
    required this.nextReviewDate,
  });
}

class SM2Algorithm {
  /// Calculates the next review date based on the user's grade.
  /// Grade scale: 0 = Hard (Forgot), 1 = Good (Remembered), 2 = Easy (Perfect)
  static SM2Response calculate({
    required int grade,
    required int currentInterval,
    required int currentRepetitions,
    required double currentEaseFactor,
  }) {
    int newInterval;
    int newRepetitions;
    double newEaseFactor;

    // Map our simple 0, 1, 2 buttons to the traditional SM-2 0-5 scale
    int sm2Grade = 0; 
    if (grade == 0) sm2Grade = 1; // Hard/Forgot
    if (grade == 1) sm2Grade = 4; // Good
    if (grade == 2) sm2Grade = 5; // Easy

    if (sm2Grade >= 3) {
      // User remembered the card
      if (currentRepetitions == 0) {
        newInterval = 1;
      } else if (currentRepetitions == 1) {
        newInterval = 6;
      } else {
        newInterval = (currentInterval * currentEaseFactor).round();
      }
      newRepetitions = currentRepetitions + 1;
    } else {
      // User forgot the card (Hard)
      newRepetitions = 0;
      newInterval = 0; // Reset interval to 0 days (due immediately/soon)
    }

    // Calculate new ease factor (Minimum is 1.3)
    newEaseFactor = currentEaseFactor +
        (0.1 - (5 - sm2Grade) * (0.08 + (5 - sm2Grade) * 0.02));
    
    if (newEaseFactor < 1.3) {
      newEaseFactor = 1.3;
    }

    // Calculate the actual next review date
    DateTime nextReviewDate = DateTime.now().add(Duration(days: newInterval));

    return SM2Response(
      interval: newInterval,
      repetitions: newRepetitions,
      easeFactor: newEaseFactor,
      nextReviewDate: nextReviewDate,
    );
  }

  /// Formats an interval in days to a human-readable string.
  static String formatInterval(int days) {
    if (days == 0) return '<10m';
    if (days == 1) return '1d';
    if (days < 30) return '${days}d';
    if (days < 365) return '${(days / 30).toStringAsFixed(1)}mo';
    return '${(days / 365).toStringAsFixed(1)}y';
  }

  /// Calculates a preview of the interval string for a given grade.
  static String previewIntervalString({
    required int grade,
    required int currentInterval,
    required int currentRepetitions,
    required double currentEaseFactor,
  }) {
    SM2Response response = calculate(
      grade: grade,
      currentInterval: currentInterval,
      currentRepetitions: currentRepetitions,
      currentEaseFactor: currentEaseFactor,
    );
    
    return formatInterval(response.interval);
  }
}