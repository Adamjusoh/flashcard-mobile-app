import 'dart:ui';
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
        'isPublic': false, // Force the downloaded copy to be private
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download deck: $e'),
            backgroundColor: Colors.redAccent,
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E3192), Color(0xFF1BAFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Discover public decks shared by Educators.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                // READ OPERATION: Querying only public decks
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('decks')
                      .where('isPublic', isEqualTo: true)
                      // Optional: Exclude the user's own public decks if they are an educator
                      // .where('authorId', isNotEqualTo: _currentUserId) 
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: Colors.white));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No public decks available right now.',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      );
                    }

                    final publicDecks = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: publicDecks.length,
                      itemBuilder: (context, index) {
                        var deckData = publicDecks[index].data() as Map<String, dynamic>;
                        String deckId = publicDecks[index].id;
                        String title = deckData['title'] ?? 'Untitled Deck';
                        
                        String authorId = deckData['authorId'] ?? '';

                        // Don't show the download button if the user actually created this public deck
                        bool isOwner = deckData['authorId'] == _currentUserId;

                        return _buildCommunityGlassCard(
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
      ),
    );
  }

  // Custom Widget for the 3D Soft Glow Glassmorphism Community Card
  Widget _buildCommunityGlassCard({
    required String title,
    required String deckId,
    required String authorId,
    required bool isOwner,
  }) {
    bool isDownloading = _downloadingDeckId == deckId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: FutureBuilder<String>(
                  future: _fetchUsername(authorId),
                  builder: (context, snapshot) {
                    final username = snapshot.data ?? '...';
                    return Row(
                      children: [
                        Icon(Icons.person_outline, color: Colors.white.withOpacity(0.7), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'by $username',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.public, color: Colors.white.withOpacity(0.5), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Community Deck',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              trailing: isOwner 
                ? const Tooltip(
                    message: "You own this deck",
                    child: Icon(Icons.person, color: Colors.white54),
                  )
                : IconButton(
                    icon: isDownloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFF1BFFFF),
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.download_rounded,
                            color: Color(0xFF1BFFFF),
                            size: 28,
                          ),
                    onPressed: isDownloading ? null : () => _downloadDeck(deckId, title),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}