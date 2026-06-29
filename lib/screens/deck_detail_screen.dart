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
        title: const Text('Delete Deck?'),
        content: const Text('Are you sure? All cards inside will be lost forever.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('decks').doc(widget.deckId).delete();
      if (mounted) {
        Navigator.pop(context); // Go back to Home Screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deck deleted successfully.'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting deck: $e'), backgroundColor: const Color(0xFFDC2626)),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: Text(
          widget.deckTitle,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (isAuthor)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AddEditDeckScreen(deckId: widget.deckId, initialTitle: widget.deckTitle),
                  ));
                } else if (value == 'delete') {
                  _deleteDeck();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Deck')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Deck', style: TextStyle(color: Color(0xFFDC2626))),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. The List of Cards
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('decks')
                  .doc(widget.deckId)
                  .collection('cards')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_add_outlined, size: 56, color: const Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        const Text(
                          'No cards in this deck yet',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final cards = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

          // 2. Bottom Action Panel
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: const Color(0xFFE2E8F0), width: 1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Study Now button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: const Text('Start Studying', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StudyScreen(deckId: widget.deckId, deckTitle: widget.deckTitle)));
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Secondary actions row
                Row(
                  children: [
                    // Share Button - Only visible to Educators
                    if (_userRole == 'Educator')
                      Expanded(
                        child: _buildSecondaryAction(
                          icon: Icons.qr_code_2_rounded,
                          label: 'Share QR',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => QRDisplayScreen(deckId: widget.deckId)));
                          },
                        ),
                      ),
                    if (_userRole == 'Educator' && isAuthor)
                      const SizedBox(width: 10),

                    // Add Card - Only visible to the author of the deck
                    if (isAuthor)
                      Expanded(
                        child: _buildSecondaryAction(
                          icon: Icons.add_rounded,
                          label: 'Add Card',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCardScreen(deckId: widget.deckId)));
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF4F46E5),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  // Helper widget for individual card list items
  Widget _buildCardTile(Map<String, dynamic> cardData, String cardId, bool isAuthor) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cardData['front'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cardData['back'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            ),
            if (isAuthor) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 18),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCardScreen(deckId: widget.deckId, cardId: cardId, initialFront: cardData['front'], initialBack: cardData['back'])));
                      },
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 18),
                      onPressed: () => _deleteCard(cardId),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}