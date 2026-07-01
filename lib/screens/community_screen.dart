import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({Key? key}) : super(key: key);

  @override
  _CommunityScreenState createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _downloadingDeckId; // Tracks which deck is currently downloading to show a spinner

  // Fetches a username string from Firestore given a uid
  Future<String> _fetchUsername(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['username'] as String? ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  // Logic to duplicate a public deck to the user's private library
  Future<void> _downloadDeck(String originalDeckId, String originalTitle) async {
    setState(() => _downloadingDeckId = originalDeckId);

    final firestore = FirebaseFirestore.instance;

    try {
      // 1. Fetch all cards inside the public deck
      final originalCardsSnapshot = await firestore
          .collection('decks')
          .doc(originalDeckId)
          .collection('cards')
          .get();

      // 2. Prepare a Firestore WriteBatch
      final batch = firestore.batch();

      // 3. Create a reference for the NEW private deck
      final newDeckRef = firestore.collection('decks').doc();
      
      batch.set(newDeckRef, {
        'title': '$originalTitle (Downloaded)',
        'authorId': _currentUserId, 
        'isPublic': true, // Keep the downloaded copy public/community
        'createdAt': Timestamp.now(),
      });

      // 4. Loop through original cards and duplicate them
      for (var cardDoc in originalCardsSnapshot.docs) {
        final newCardRef = newDeckRef.collection('cards').doc();
        final cardData = cardDoc.data();
        
        batch.set(newCardRef, {
          'front': cardData['front'],
          'back': cardData['back'],
          // Reset SM-2 algorithm stats for the new student
          'interval': 0,
          'repetitions': 0,
          'easeFactor': 2.5,
          'nextReviewDate': Timestamp.now(), 
        });
      }

      // 5. Execute the batch write
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deck saved to your library!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download deck: $e'),
            backgroundColor: const Color(0xFFDC2626),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explore',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Discover public decks shared by Educators.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              // READ OPERATION: Querying only public decks
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('decks')
                    .where('isPublic', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.explore_outlined, size: 56, color: const Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
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
                      
                      // Don't show the download button if the user actually created this public deck
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

  // Clean community deck card
  Widget _buildCommunityCard({
    required String title,
    required String deckId,
    required String authorId,
    required bool isOwner,
  }) {
    bool isDownloading = _downloadingDeckId == deckId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              // Icon
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0ABFC).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.public_rounded, color: Color(0xFFA855F7), size: 22),
              ),
              const SizedBox(width: 14),
              // Title and label
              Expanded(
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
                          'by $username · Community Deck',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Action
              if (isOwner)
                Tooltip(
                  message: 'You own this deck',
                  child: Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF94A3B8), size: 18),
                  ),
                )
              else
                SizedBox(
                  height: 36,
                  width: 36,
                  child: isDownloading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            color: Color(0xFF4F46E5),
                            strokeWidth: 2.5,
                          ),
                        )
                      : IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.download_rounded,
                            color: Color(0xFF4F46E5),
                            size: 22,
                          ),
                          onPressed: () => _downloadDeck(deckId, title),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}