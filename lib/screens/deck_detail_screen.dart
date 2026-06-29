import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'study_screen.dart';
import 'add_edit_card_screen.dart';
import 'qr_display_screen.dart';
import 'add_edit_deck_screen.dart';

class DeckDetailScreen extends StatefulWidget {
  final String deckId;
  final String deckTitle;
  final String authorId;

  const DeckDetailScreen({
    Key? key,
    required this.deckId,
    required this.deckTitle,
    required this.authorId,
  }) : super(key: key);

  @override
  _DeckDetailScreenState createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  String _userRole = 'Student'; // Default to student
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  // Fetch the current user's role to determine UI permissions (Requirement 4)
  Future<void> _fetchUserRole() async {
    if (_currentUserId.isEmpty) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
    if (userDoc.exists && mounted) {
      setState(() {
        _userRole = userDoc.data()?['role'] ?? 'Student';
      });
    }
  }

  // DELETE operation for the entire deck (Requirement 5)
  Future<void> _deleteDeck() async {
    // Show confirmation dialog first
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E3192),
        title: const Text('Delete Deck?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure? All cards inside will be lost forever.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('decks').doc(widget.deckId).delete();
      if (mounted) {
        Navigator.pop(context); // Go back to Home Screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deck deleted successfully.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting deck: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // DELETE operation for a single card
  Future<void> _deleteCard(String cardId) async {
    try {
      await FirebaseFirestore.instance
          .collection('decks')
          .doc(widget.deckId)
          .collection('cards')
          .doc(cardId)
          .delete();
    } catch (e) {
      print("Error deleting card: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAuthor = _currentUserId == widget.authorId;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.deckTitle, style: const TextStyle(color: Colors.white)),
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
          child: Column(
            children: [
              // 1. The List of Cards (Moved to the TOP)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('decks')
                      .doc(widget.deckId)
                      .collection('cards')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No cards in this deck yet.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      );
                    }

                    final cards = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        var cardData = cards[index].data() as Map<String, dynamic>;
                        String cardId = cards[index].id;

                        return _buildCardTile(cardData, cardId, isAuthor);
                      },
                    );
                  },
                ),
              ),

              // 2. Dashboard / Action Panel (Moved to the BOTTOM for reachability)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF2E3192),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 28),
                              label: const Text('STUDY NOW', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => StudyScreen(deckId: widget.deckId, deckTitle: widget.deckTitle)));
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Share Button - Only visible to Educators
                              if (_userRole == 'Educator')
                                _buildActionIcon(
                                  icon: Icons.qr_code_2_rounded,
                                  label: 'Share',
                                  color: Colors.greenAccent,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => QRDisplayScreen(deckId: widget.deckId)));
                                  },
                                ),

                              // Edit, Delete & Add Card - Only visible to the author of the deck
                              if (isAuthor) ...[
                                _buildActionIcon(
                                  icon: Icons.add_circle_outline_rounded,
                                  label: 'Add Card',
                                  color: Colors.blueAccent, // Added the creation button here
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCardScreen(deckId: widget.deckId)));
                                  },
                                ),
                                _buildActionIcon(
                                  icon: Icons.edit_rounded,
                                  label: 'Edit',
                                  color: Colors.orangeAccent,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditDeckScreen(deckId: widget.deckId, initialTitle: widget.deckTitle)));
                                  },
                                ),
                                _buildActionIcon(
                                  icon: Icons.delete_rounded,
                                  label: 'Delete',
                                  color: Colors.redAccent,
                                  onTap: _deleteDeck,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
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

  // Helper widget for action icons in the dashboard
  Widget _buildActionIcon({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }

  // Helper widget for individual card list items
  Widget _buildCardTile(Map<String, dynamic> cardData, String cardId, bool isAuthor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        title: Text(
          cardData['front'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          cardData['back'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        trailing: isAuthor
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orangeAccent, size: 20),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCardScreen(deckId: widget.deckId, cardId: cardId, initialFront: cardData['front'], initialBack: cardData['back'])));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
              onPressed: () => _deleteCard(cardId),
            ),
          ],
        )
            : null,
      ),
    );
  }
}