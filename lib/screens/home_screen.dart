import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import the Deck Detail Screen to navigate to it
import 'deck_detail_screen.dart';

// Curated palette for deck cards — each deck gets a unique accent
const List<Color> _deckColors = [
  Color(0xFFF43F5E), // Rose
  Color(0xFF6366F1), // Indigo
  Color(0xFF14B8A6), // Teal
  Color(0xFFF59E0B), // Amber
  Color(0xFF8B5CF6), // Violet
  Color(0xFF10B981), // Emerald
  Color(0xFFEC4899), // Pink
  Color(0xFF3B82F6), // Blue
  Color(0xFFEF4444), // Red
  Color(0xFF06B6D4), // Cyan
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient greeting header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_getGreeting()} 👋',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ready to learn something new?',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Section label
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'My Library',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('decks')
                    .where('authorId', isEqualTo: currentUserId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                            'No decks yet',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the + button to create one!',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  final decks = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: decks.length,
                    itemBuilder: (context, index) {
                      var deckData = decks[index].data() as Map<String, dynamic>;
                      String deckId = decks[index].id;
                      String title = deckData['title'] ?? 'Untitled Deck';
                      bool isPublic = deckData['isPublic'] ?? false;
                      String authorId = deckData['authorId'] ?? currentUserId;
                      Color accentColor = _deckColors[index % _deckColors.length];

                      return _buildDeckCard(context, title, isPublic, deckId, authorId, accentColor);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckCard(
      BuildContext context, String title, bool isPublic, String deckId, String authorId, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => DeckDetailScreen(
                  deckId: deckId,
                  deckTitle: title,
                  authorId: authorId,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 250),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
            ),
            child: Row(
              children: [
                // Colored accent strip
                Container(
                  width: 5,
                  height: 80,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Deck icon in colored circle
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.style_rounded, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                // Title + subtitle
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                              size: 13,
                              color: const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPublic ? 'Community Deck' : 'Private Deck',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(Icons.chevron_right_rounded, color: accentColor.withValues(alpha: 0.5), size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}