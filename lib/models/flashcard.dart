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
  final DateTime? nextReviewDate;
  final DateTime? createdAt;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.interval = 0,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.nextReviewDate,
    this.createdAt,
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
      nextReviewDate: (data['nextReviewDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'front': front,
      'back': back,
      'interval': interval,
      'repetitions': repetitions,
      'easeFactor': easeFactor,
      'nextReviewDate': nextReviewDate != null ? Timestamp.fromDate(nextReviewDate!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  /// Calculates the mastery level based on SM-2 state.
  MasteryLevel get masteryLevel {
    if (repetitions == 0) return MasteryLevel.newCard;
    if (interval < 21) return MasteryLevel.learning;
    return MasteryLevel.review;
  }

  /// Returns a human-readable tag for the mastery level.
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

  /// Helper to check if a card is currently due.
  bool isDue() {
    if (nextReviewDate == null) return true; // New cards are inherently due
    final now = DateTime.now();
    return nextReviewDate!.isBefore(now) || nextReviewDate!.isAtSameMomentAs(now);
  }
}
