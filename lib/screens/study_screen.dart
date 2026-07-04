import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/sm2_algorithm.dart';

class StudyScreen extends StatefulWidget {
  final String deckId;
  final String deckTitle;

  const StudyScreen({super.key, required this.deckId, required this.deckTitle});

  @override
  _StudyScreenState createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  List<QueryDocumentSnapshot> _allCards = [];
  int _totalCardsCount = 0;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllCardsAndSort();
  }

  // 1. Fetch ALL cards (No locking) and sort by Difficulty
  Future<void> _fetchAllCardsAndSort() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('decks')
          .doc(widget.deckId)
          .collection('cards')
          .get();

      List<QueryDocumentSnapshot> allDocs = snapshot.docs.toList();
      int totalCount = allDocs.length;
      final now = DateTime.now();

      // Filter to maximize SM-2 algorithm: Only cards due today or earlier
      List<QueryDocumentSnapshot> dueCards = allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final nextReviewDate = (data['nextReviewDate'] as Timestamp?)?.toDate();
        if (nextReviewDate == null) return true; // New cards are due
        return nextReviewDate.isBefore(now) || nextReviewDate.isAtSameMomentAs(now);
      }).toList();

      // Sort locally: Hardest cards (lowest easeFactor) appear first!
      dueCards.sort((a, b) {
        double easeA = (a.data() as Map<String, dynamic>)['easeFactor'] ?? 2.5;
        double easeB = (b.data() as Map<String, dynamic>)['easeFactor'] ?? 2.5;
        return easeA.compareTo(easeB);
      });

      setState(() {
        _totalCardsCount = totalCount;
        _allCards = dueCards;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching cards: $e");
      setState(() => _isLoading = false);
    }
  }

  // 2. SM-2 Database Update & Move to Next Card
  Future<void> _handleGrade(int grade) async {
    if (_currentIndex >= _allCards.length) return;

    final cardDoc = _allCards[_currentIndex];
    final cardData = cardDoc.data() as Map<String, dynamic>;

    SM2Response result = SM2Algorithm.calculate(
      grade: grade,
      currentInterval: cardData['interval'] ?? 0,
      currentRepetitions: cardData['repetitions'] ?? 0,
      currentEaseFactor: (cardData['easeFactor'] ?? 2.5).toDouble(),
    );

    // Update the database with the new stats behind the scenes
    await FirebaseFirestore.instance
        .collection('decks')
        .doc(widget.deckId)
        .collection('cards')
        .doc(cardDoc.id)
        .update({
      'interval': result.interval,
      'repetitions': result.repetitions,
      'easeFactor': result.easeFactor,
      'nextReviewDate': Timestamp.fromDate(result.nextReviewDate),
    });

    // Move to the next card and reset flip state
    setState(() {
      _isFlipped = false;
      _currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: Text(
          widget.deckTitle,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
            : _allCards.isEmpty
            ? _buildEmptyState()
            : _buildStudyInterface(),
      ),
    );
  }

  Widget _buildEmptyState() {
    bool isCaughtUp = _totalCardsCount > 0 && _allCards.isEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCaughtUp ? Icons.check_circle_outline_rounded : Icons.style_outlined, 
            size: 64, 
            color: isCaughtUp ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)
          ),
          const SizedBox(height: 16),
          Text(
            isCaughtUp ? "You're all caught up!" : 'This deck is empty!',
            style: const TextStyle(fontSize: 20, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            isCaughtUp ? "No cards due for review right now." : 'Add some cards to start studying.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4F46E5),
              side: const BorderSide(color: Color(0xFF4F46E5)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyInterface() {
    // Check if we finished all cards in the deck
    if (_currentIndex >= _allCards.length) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.emoji_events_rounded, size: 44, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Deck Completed!',
                style: TextStyle(fontSize: 24, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You reviewed all due cards.',
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Exit'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      // Restart the session
                      setState(() {
                        _isLoading = true;
                        _currentIndex = 0;
                        _isFlipped = false;
                      });
                      _fetchAllCardsAndSort();
                    },
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final currentCardDoc = _allCards[_currentIndex];
    final currentCard = currentCardDoc.data() as Map<String, dynamic>;

    return Column(
      children: [
        // Progress bar + counter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Card ${_currentIndex + 1} of ${_allCards.length}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _getDifficultyLabel(currentCard['easeFactor'] ?? 2.5),
                    style: TextStyle(
                      color: _getDifficultyColor(currentCard['easeFactor'] ?? 2.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _allCards.length,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // 3. Swipeable & Flippable Card
        Dismissible(
          key: Key(currentCardDoc.id), // Unique key for the swiper
          direction: DismissDirection.horizontal, // Only allow left/right swipes

          // Background when swiping RIGHT (Hard)
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.replay_rounded, color: const Color(0xFFDC2626).withValues(alpha: 0.7), size: 44),
                const SizedBox(height: 6),
                Text('AGAIN', style: TextStyle(color: const Color(0xFFDC2626).withValues(alpha: 0.7), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),

          // Background when swiping LEFT (Easy)
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF16A34A).withValues(alpha: 0.7), size: 44),
                const SizedBox(height: 6),
                Text('EASY', style: TextStyle(color: const Color(0xFF16A34A).withValues(alpha: 0.7), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),

          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              _handleGrade(2); // Swipe Left = Easy
            } else {
              _handleGrade(0); // Swipe Right = Hard
            }
          },

          child: GestureDetector(
            onTap: () {
              // Now toggles back and forth infinitely!
              setState(() => _isFlipped = !_isFlipped);
            },
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: _isFlipped ? pi : 0),
              duration: const Duration(milliseconds: 400),
              builder: (context, double value, child) {
                bool isBack = value >= (pi / 2);

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(value),
                  child: isBack
                      ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildCardFace(currentCard['back'] ?? '', isFront: false),
                  )
                      : _buildCardFace(currentCard['front'] ?? '', isFront: true),
                );
              },
            ),
          ),
        ),

        const Spacer(),

        // 4. Rating buttons — always visible after flip
        AnimatedOpacity(
          opacity: _isFlipped ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_isFlipped,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0, left: 20, right: 20),
              child: Row(
                children: [
                  Expanded(child: _buildGradeButton(0, 'Again', const Color(0xFFDC2626))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildGradeButton(1, 'Good', const Color(0xFFF59E0B))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildGradeButton(2, 'Easy', const Color(0xFF16A34A))),
                ],
              ),
            ),
          ),
        ),

        // Tap hint when not flipped
        if (!_isFlipped)
          const Padding(
            padding: EdgeInsets.only(bottom: 24.0),
            child: Text(
              'Tap card to reveal answer',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }

  // Helper widget to construct clean card faces
  Widget _buildCardFace(String text, {required bool isFront}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.88,
      height: 420,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Label
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isFront
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                      : const Color(0xFF16A34A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFront ? 'QUESTION' : 'ANSWER',
                  style: TextStyle(
                    color: isFront ? const Color(0xFF4F46E5) : const Color(0xFF16A34A),
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 60),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  height: 1.4,
                ),
              ),
            ),
          ),
          // Tap hint
          const Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Tap to flip',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeButton(int grade, String label, Color color) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: () => _handleGrade(grade),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.1),
          foregroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  String _getDifficultyLabel(double easeFactor) {
    if (easeFactor < 2.0) return 'Hard';
    if (easeFactor > 2.6) return 'Easy';
    return 'Normal';
  }

  Color _getDifficultyColor(double easeFactor) {
    if (easeFactor < 2.0) return const Color(0xFFDC2626);
    if (easeFactor > 2.6) return const Color(0xFF16A34A);
    return const Color(0xFFF59E0B);
  }
}