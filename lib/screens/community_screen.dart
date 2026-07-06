import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Curated pastel palette for community deck cards
const List<Color> _communityColors = [
  Color(0xFFA78BFA), // Violet
  Color(0xFFF472B6), // Pink
  Color(0xFF38BDF8), // Sky
  Color(0xFF34D399), // Emerald
  Color(0xFFFBBF24), // Amber
  Color(0xFFF87171), // Red
  Color(0xFF2DD4BF), // Teal
  Color(0xFF818CF8), // Indigo
];

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _downloadingDeckId;

  Future<String> _fetchUsername(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['username'] as String? ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  Color _colorFromTitle(String title) {
    int hash = title.hashCode.abs();
    return _communityColors[hash % _communityColors.length];
  }

  Future<void> _downloadDeck(String originalDeckId, String originalTitle) async {
    setState(() => _downloadingDeckId = originalDeckId);

    final firestore = FirebaseFirestore.instance;

    try {
      final originalCardsSnapshot = await firestore
          .collection('decks')
          .doc(originalDeckId)
          .collection('cards')
          .get();

      final batch = firestore.batch();
      final newDeckRef = firestore.collection('decks').doc();

      batch.set(newDeckRef, {
        'title': originalTitle,
        'authorId': _currentUserId,
        'isPublic': false,
        'createdAt': Timestamp.now(),
      });

      for (var cardDoc in originalCardsSnapshot.docs) {
        final newCardRef = newDeckRef.collection('cards').doc();
        final cardData = cardDoc.data();

        batch.set(newCardRef, {
          'front': cardData['front'],
          'back': cardData['back'],
          'interval': 0,
          'repetitions': 0,
          'easeFactor': 2.5,
          'nextReviewDate': Timestamp.now(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Deck saved to your library! 🎉'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download deck: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingDeckId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
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
                  const Text(
                    'Explore 🌎',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Discover decks shared by Educators',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('decks')
                    .where('isPublic', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 72,
                            width: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.explore_outlined, size: 36, color: Color(0xFF8B5CF6)),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No public decks available right now.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  }

                  final publicDecks = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: publicDecks.length,
                    itemBuilder: (context, index) {
                      var deckData = publicDecks[index].data() as Map<String, dynamic>;
                      String deckId = publicDecks[index].id;
                      String title = deckData['title'] ?? 'Untitled Deck';
                      String authorId = deckData['authorId'] ?? '';
                      bool isOwner = deckData['authorId'] == _currentUserId;

                      return _buildCommunityCard(
                        title: title,
                        deckId: deckId,
                        authorId: authorId,
                        isOwner: isOwner,
                      );
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

  Widget _buildCommunityCard({
    required String title,
    required String deckId,
    required String authorId,
    required bool isOwner,
  }) {
    bool isDownloading = _downloadingDeckId == deckId;
    Color accent = _colorFromTitle(title);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        ),
        child: Row(
          children: [
            // Accent strip
            Container(
              width: 5,
              height: 76,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Icon
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.public_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            // Title and label
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<String>(
                      future: _fetchUsername(authorId),
                      builder: (context, snapshot) {
                        final username = snapshot.data ?? '...';
                        return Text(
                          'by $username',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Action
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: isOwner
                  ? Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_rounded, color: Color(0xFF94A3B8), size: 18),
                    )
                  : isDownloading
                      ? const SizedBox(
                          height: 36,
                          width: 36,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              color: Color(0xFF8B5CF6),
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.download_rounded, color: accent, size: 20),
                            onPressed: () => _downloadDeck(deckId, title),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}