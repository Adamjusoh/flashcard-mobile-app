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
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  String _username = '';
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (_currentUserId.isEmpty) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
    if (userDoc.exists && mounted) {
      setState(() {
        _username = userDoc.data()?['username'] ?? '';
      });
    }
  }

  Future<void> _deleteDeck() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Deck?'),
        content: const Text('Are you sure? All cards inside will be lost forever.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('decks').doc(widget.deckId).delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Deck deleted successfully.'),
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting deck: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _deleteCard(String cardId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Card?'),
        content: const Text('Are you sure you want to delete this card?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
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
          SnackBar(
            content: const Text('Card deleted.'),
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting card: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAuthor = _currentUserId == widget.authorId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Gradient header banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: Column(
                children: [
                  // Top bar with back button and menu
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      if (isAuthor)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
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
                              child: Text('Delete Deck', style: TextStyle(color: Color(0xFFEF4444))),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Deck icon & title
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.style_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.deckTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Card count and stats from stream below
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('decks')
                        .doc(widget.deckId)
                        .collection('cards')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final cards = snapshot.data?.docs ?? [];
                      final count = cards.length;
                      
                      int newCount = 0;
                      int learningCount = 0;
                      int reviewCount = 0;
                      
                      for (var doc in cards) {
                        final card = Flashcard.fromFirestore(doc);
                        if (card.masteryLevel == MasteryLevel.newCard) newCount++;
                        else if (card.masteryLevel == MasteryLevel.learning) learningCount++;
                        else reviewCount++;
                      }
                      
                      return Column(
                        children: [
                          Text(
                            '$count cards',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatPill('New', newCount, const Color(0xFF3B82F6)),
                                const SizedBox(width: 8),
                                _buildStatPill('Learning', learningCount, const Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                _buildStatPill('Review', reviewCount, const Color(0xFF10B981)),
                              ],
                            ),
                          ]
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Card list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('decks')
                  .doc(widget.deckId)
                  .collection('cards')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.note_add_outlined, size: 32, color: Color(0xFF6366F1)),
                        ),
                        const SizedBox(height: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    Flashcard card = Flashcard.fromFirestore(cards[index]);
                    return _buildCardTile(card, isAuthor);
                  },
                );
              },
            ),
          ),

          // Bottom Action Panel
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient Study Now button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => StudyScreen(deckId: widget.deckId, deckTitle: widget.deckTitle)));
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 24, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Start Studying', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Secondary actions row
                Row(
                  children: [
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
                    if (isAuthor) const SizedBox(width: 10),
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

  Widget _buildStatPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            '$count',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6366F1),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildCardTile(Flashcard card, bool isAuthor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        ),
        child: Row(
          children: [
            // Mastery-colored accent strip
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: _getMasteryColor(card.masteryLevel),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          const SizedBox(height: 4),
                          Text(
                            card.back,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (card.isDue())
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Due',
                                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getMasteryColor(card.masteryLevel).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                card.masteryTag,
                                style: TextStyle(
                                  color: _getMasteryColor(card.masteryLevel),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isAuthor) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 16),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCardScreen(deckId: widget.deckId, cardId: card.id, initialFront: card.front, initialBack: card.back)));
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
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
        return const Color(0xFF10B981); // Emerald
    }
  }
}