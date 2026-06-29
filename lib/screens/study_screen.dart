import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/sm2_algorithm.dart';

class StudyScreen extends StatefulWidget {
  final String deckId;
  final String deckTitle;

  const StudyScreen({Key? key, required this.deckId, required this.deckTitle}) : super(key: key);

  @override
  _StudyScreenState createState() => _StudyScreenState();
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

  // 1. Fetch ALL cards (No locking) and sort by Difficulty
  Future<void> _fetchAllCardsAndSort() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('decks')
          .doc(widget.deckId)
          .collection('cards')
          .get();

      List<QueryDocumentSnapshot> cards = snapshot.docs.toList();

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
      print("Error fetching cards: $e");
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.deckTitle, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _allCards.isEmpty
              ? _buildEmptyState()
              : _buildStudyInterface(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style, size: 80, color: Colors.white54),
          const SizedBox(height: 20),
          const Text(
            "This deck is empty!",
            style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2E3192),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Go Back"),
          )
        ],
      ),
    );
  }

  Widget _buildStudyInterface() {
    // Check if we finished all cards in the deck
    if (_currentIndex >= _allCards.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              "Deck Completed!",
              style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "You reviewed all ${_allCards.length} cards.",
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Exit"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2E3192),
                  ),
                  onPressed: () {
                    // Restart the session
                    setState(() {
                      _currentIndex = 0;
                      _isFlipped = false;
                    });
                  },
                  child: const Text("Study Again"),
                ),
              ],
            )
          ],
        ),
      );
    }

    final currentCardDoc = _allCards[_currentIndex];
    final currentCard = currentCardDoc.data() as Map<String, dynamic>;

    return Column(
      children: [
        // Progress Indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Card ${_currentIndex + 1} of ${_allCards.length}",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              Text(
                "Difficulty: ${_getDifficultyLabel(currentCard['easeFactor'] ?? 2.5)}",
                style: const TextStyle(color: Colors.white54, fontSize: 14),
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
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 50),
                SizedBox(height: 8),
                Text("HARD", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Background when swiping LEFT (Easy)
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 40.0),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 50),
                SizedBox(height: 8),
                Text("EASY", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
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

        // 4. Instructional text or Bottom Action Bar
        AnimatedOpacity(
          opacity: _isFlipped ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !_isFlipped,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0, left: 24, right: 24),
              child: Column(
                children: [
                  Text(
                    "Swipe Left for EASY • Swipe Right for HARD",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildGradeButton(0, "Hard", Colors.redAccent),
                      _buildGradeButton(1, "Good", Colors.orangeAccent),
                      _buildGradeButton(2, "Easy", Colors.greenAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Helper widget to construct the Glassmorphism card faces
  Widget _buildCardFace(String text, {required bool isFront}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: 450, // Made slightly taller for better swiping real estate
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isFront ? 0.1 : 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Stack(
            children: [
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    isFront ? "FRONT" : "BACK",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    "Tap to flip",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeButton(int grade, String label, Color color) {
    return GestureDetector(
      onTap: () => _handleGrade(grade),
      child: Container(
        height: 50,
        width: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color.withOpacity(0.8), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              shadows: [Shadow(color: color, blurRadius: 5)],
            ),
          ),
        ),
      ),
    );
  }

  String _getDifficultyLabel(double easeFactor) {
    if (easeFactor < 2.0) return "Hard";
    if (easeFactor > 2.6) return "Easy";
    return "Normal";
  }
}