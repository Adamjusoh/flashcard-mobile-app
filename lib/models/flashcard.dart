import 'package:cloud_firestore/cloud_firestore.dart';

enum MasteryLevel {
  newCard,
  learning,
  review,
}

class Flashcard {
  final String id;
  final String front;
  final String back;
  final int interval;
  final int repetitions;
  final double easeFactor;
  final Timestamp nextReviewDate;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.interval,
    required this.repetitions,
    required this.easeFactor,
    required this.nextReviewDate,
  });

  factory Flashcard.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Flashcard(
      id: doc.id,
      front: data['front'] ?? '',
      back: data['back'] ?? '',
      interval: data['interval'] ?? 0,
      repetitions: data['repetitions'] ?? 0,
      easeFactor: (data['easeFactor'] ?? 2.5).toDouble(),
      nextReviewDate: data['nextReviewDate'] ?? Timestamp.now(),
    );
  }

  bool isDue() {
    if (interval == 0) return true; // Cards with interval 0 (new or hard) are always due immediately
    final now = Timestamp.now().toDate();
    final reviewDate = nextReviewDate.toDate();
    return now.isAfter(reviewDate) || now.isAtSameMomentAs(reviewDate);
  }

  MasteryLevel get masteryLevel {
    if (repetitions == 0 && interval == 0) return MasteryLevel.newCard;
    if (interval < 21) return MasteryLevel.learning; // Under 3 weeks interval is learning
    return MasteryLevel.review; // Over 3 weeks interval is review/mastered
  }

  String get masteryTag {
    switch (masteryLevel) {
      case MasteryLevel.newCard:
        return 'New';
      case MasteryLevel.learning:
        return 'Learning';
      case MasteryLevel.review:
        return 'Review';
    }
  }
}
