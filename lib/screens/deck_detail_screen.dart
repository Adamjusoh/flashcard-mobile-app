import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flashcard.dart';

import 'study_screen.dart';
import 'add_edit_card_screen.dart';
import 'qr_display_screen.dart';
import 'add_edit_deck_screen.dart';

class DeckDetailScreen extends StatefulWidget {
  final String deckId;
  final String deckTitle;
  final String authorId;

  const DeckDetailScreen({
    super.key,
    required this.deckId,
    required this.deckTitle,
    required this.authorId,
  });

  @override
  _DeckDetailScreenState createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  String _username = ''; // Current user's username for sharing
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Fetch the current user's role and username
  Future<void> _fetchUserData() async {
    if (_currentUserId.isEmpty) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
    if (userDoc.exists && mounted) {
      setState(() {
        _username = userDoc.data()?['username'] ?? '';
      });
    }
  }

  // DELETE operation for the entire deck
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting deck: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  // DELETE operation for a single card — with confirmation dialog
  Future<void> _deleteCard(String cardId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Card?'),
        content: const Text('Are you sure you want to delete this card?'),
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
      await FirebaseFirestore.instance
          .collection('decks')
          .doc(widget.deckId)
          .collection('cards')
          .doc(cardId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card deleted.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting card: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_add_outlined, size: 56, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text(
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
                    Flashcard card = Flashcard.fromFirestore(cards[index]);
                    return _buildCardTile(card, isAuthor);
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
              border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
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
                    // Share Button - Visible to any author of the deck (Educator or Student)
                    if (isAuthor)
                      Expanded(
                        child: _buildSecondaryAction(
                          icon: Icons.qr_code_2_rounded,
                          label: 'Share QR',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QRDisplayScreen(
                                  deckId: widget.deckId,
                                  username: _username,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (isAuthor)
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
  Widget _buildCardTile(Flashcard card, bool isAuthor) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.08),
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
                    card.front,
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
                    card.back,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getMasteryColor(card.masteryLevel).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _getMasteryColor(card.masteryLevel).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    card.masteryTag,
                    style: TextStyle(
                      color: _getMasteryColor(card.masteryLevel),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isAuthor) ...[
                  const SizedBox(height: 8),
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
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCardScreen(deckId: widget.deckId, cardId: card.id, initialFront: card.front, initialBack: card.back)));
                          },
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 18),
                          onPressed: () => _deleteCard(card.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getMasteryColor(MasteryLevel level) {
    switch (level) {
      case MasteryLevel.newCard:
        return const Color(0xFF3B82F6); // Blue
      case MasteryLevel.learning:
        return const Color(0xFFF59E0B); // Amber
      case MasteryLevel.review:
        return const Color(0xFF16A34A); // Green
    }
  }
}