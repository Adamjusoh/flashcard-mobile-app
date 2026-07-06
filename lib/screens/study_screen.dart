import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/sm2_algorithm.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flashcard.dart';

class StudyScreen extends StatefulWidget {
  final String deckId;
  final String deckTitle;

  const StudyScreen({super.key, required this.deckId, required this.deckTitle});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  List<QueryDocumentSnapshot> _allCards = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllCardsAndSort();
  }

  // 1. Fetch Due cards and sort by Difficulty
  Future<void> _fetchAllCardsAndSort() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('decks')
          .doc(widget.deckId)
          .collection('cards')
          .get();

      List<QueryDocumentSnapshot> allDocs = snapshot.docs.toList();
      
      // Filter for cards that are due
      List<QueryDocumentSnapshot> cards = allDocs.where((doc) {
        return Flashcard.fromFirestore(doc).isDue();
      }).toList();

      // Sort locally: Hardest cards (lowest easeFactor) appear first!
      cards.sort((a, b) {
        double easeA = (a.data() as Map<String, dynamic>)['easeFactor'] ?? 2.5;
        double easeB = (b.data() as Map<String, dynamic>)['easeFactor'] ?? 2.5;
        return easeA.compareTo(easeB);
      });

      setState(() {
        _allCards = cards;
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
    
    // Check if we just finished the deck
    if (_currentIndex >= _allCards.length && _allCards.isNotEmpty) {
      _updateStreak();
    }
  }

  Future<void> _updateStreak() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final userDoc = await userRef.get();
    
    if (userDoc.exists) {
      final data = userDoc.data()!;
      final lastStudyDate = (data['lastStudyDate'] as Timestamp?)?.toDate();
      int currentStreak = data['currentStreak'] ?? 0;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      if (lastStudyDate != null) {
        final lastDate = DateTime(lastStudyDate.year, lastStudyDate.month, lastStudyDate.day);
        final difference = today.difference(lastDate).inDays;
        
        if (difference == 1) {
          // Studied yesterday, increment streak
          currentStreak += 1;
        } else if (difference > 1) {
          // Missed a day, reset streak
          currentStreak = 1;
        }
        // if difference == 0, already studied today, do nothing to streak
      } else {
        // First time studying
        currentStreak = 1;
      }
      
      await userRef.update({
        'lastStudyDate': Timestamp.fromDate(now),
        'currentStreak': currentStreak,
      });
    }
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
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
            : _allCards.isEmpty
            ? _buildEmptyState()
            : _buildStudyInterface(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.style_outlined, size: 40, color: Color(0xFF6366F1)),
          ),
          const SizedBox(height: 20),
          const Text(
            'This deck is empty!',
            style: TextStyle(fontSize: 20, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add some cards to start studying.',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6366F1),
              side: const BorderSide(color: Color(0xFF6366F1)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      return _buildCompletionScreen();
    }

    final currentCardDoc = _allCards[_currentIndex];
    final currentCard = currentCardDoc.data() as Map<String, dynamic>;

    return Column(
      children: [
        // Gradient progress bar + counter
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(currentCard['easeFactor'] ?? 2.5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getDifficultyLabel(currentCard['easeFactor'] ?? 2.5),
                      style: TextStyle(
                        color: _getDifficultyColor(currentCard['easeFactor'] ?? 2.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (_currentIndex + 1) / _allCards.length,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // 3. Swipeable & Flippable Card
        Dismissible(
          key: Key(currentCardDoc.id),
          direction: DismissDirection.horizontal,

          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.replay_rounded, color: const Color(0xFFEF4444).withValues(alpha: 0.7), size: 44),
                const SizedBox(height: 6),
                Text('HARD', style: TextStyle(color: const Color(0xFFEF4444).withValues(alpha: 0.7), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),

          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF10B981).withValues(alpha: 0.7), size: 44),
                const SizedBox(height: 6),
                Text('EASY', style: TextStyle(color: const Color(0xFF10B981).withValues(alpha: 0.7), fontWeight: FontWeight.bold, fontSize: 13)),
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

        // 4. Rating buttons — vibrant filled style
        AnimatedOpacity(
          opacity: _isFlipped ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_isFlipped,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0, left: 20, right: 20),
              child: Row(
                children: [
                  Expanded(child: _buildGradeButton(0, 'Hard', const Color(0xFFEF4444))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildGradeButton(1, 'Normal', const Color(0xFFF59E0B))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildGradeButton(2, 'Easy', const Color(0xFF10B981))),
                ],
              ),
            ),
          ),
        ),

        // Tap hint when not flipped
        if (!_isFlipped)
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_outlined, size: 16, color: const Color(0xFF94A3B8).withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                const Text(
                  'Tap card to reveal answer',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCompletionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji celebration
            const Text(
              '🎉',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '🏆  Deck Completed!  ⭐',
                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You reviewed all ${_allCards.length} cards.',
              style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Great job keeping up with your reviews!',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Exit'),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _currentIndex = 0;
                          _isFlipped = false;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Study Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to construct clean card faces
  Widget _buildCardFace(String text, {required bool isFront}) {
    final Color accentColor = isFront ? const Color(0xFF6366F1) : const Color(0xFF10B981);

    return Container(
      width: MediaQuery.of(context).size.width * 0.88,
      height: 420,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle gradient accent at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isFront
                      ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                      : [const Color(0xFF10B981), const Color(0xFF06B6D4)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
          ),
          // Label
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFront ? 'QUESTION' : 'ANSWER',
                  style: TextStyle(
                    color: accentColor,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          height: 1.4,
                        ),
                        textAlign: WrapAlignment.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tap hint
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_outlined, size: 14, color: const Color(0xFF94A3B8).withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  const Text(
                    'Tap to flip',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeButton(int grade, String label, Color color) {
    return SizedBox(
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _handleGrade(grade),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
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
    if (easeFactor < 2.0) return const Color(0xFFEF4444);
    if (easeFactor > 2.6) return const Color(0xFF10B981);
    return const Color(0xFFF59E0B);
  }
}