import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddEditCardScreen extends StatefulWidget {
  // deckId is ALWAYS required so we know where to save the card.
  final String deckId;
  
  // If cardId is provided, the screen acts in "Edit" mode.
  // If cardId is null, it acts in "Create" mode.
  final String? cardId;
  final String? initialFront;
  final String? initialBack;

  const AddEditCardScreen({
    Key? key,
    required this.deckId,
    this.cardId,
    this.initialFront,
    this.initialBack,
  }) : super(key: key);

  @override
  _AddEditCardScreenState createState() => _AddEditCardScreenState();
}

class _AddEditCardScreenState extends State<AddEditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _frontController = TextEditingController();
  final TextEditingController _backController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if we are in Edit Mode
    if (widget.initialFront != null) {
      _frontController.text = widget.initialFront!;
    }
    if (widget.initialBack != null) {
      _backController.text = widget.initialBack!;
    }
  }

  // 1. The Core CRUD Logic: Create and Update Subcollections (Requirement 5)
  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final firestore = FirebaseFirestore.instance;
    // We target the specific 'cards' subcollection inside the parent 'deck'
    final cardsCollection = firestore
        .collection('decks')
        .doc(widget.deckId)
        .collection('cards');

    try {
      if (widget.cardId == null) {
        // CREATE MODE: We must initialize the SM-2 variables here!
        await cardsCollection.add({
          'front': _frontController.text.trim(),
          'back': _backController.text.trim(),
          'interval': 0,                   // SM-2: Start at 0 days
          'repetitions': 0,                // SM-2: 0 correct streak
          'easeFactor': 2.5,               // SM-2: Default ease factor
          'nextReviewDate': Timestamp.now(), // Due immediately
        });
      } else {
        // UPDATE MODE: Only update text. DO NOT reset the student's SM-2 progress!
        await cardsCollection.doc(widget.cardId).update({
          'front': _frontController.text.trim(),
          'back': _backController.text.trim(),
        });
      }

      // Success, pop the screen
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.cardId == null ? 'Card added!' : 'Card updated!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving card: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditMode = widget.cardId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: Text(
          isEditMode ? 'Edit Card' : 'Add New Card',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Front (Question) field
              const Text(
                'Front (Question)',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _frontController,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16),
                maxLines: 4,
                minLines: 2,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Enter the question...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the front of the card.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Back (Answer) field
              const Text(
                'Back (Answer)',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _backController,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16),
                maxLines: 5,
                minLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Enter the answer...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the back of the card.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 36),

              // Save Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                  : SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveCard,
                        child: Text(
                          isEditMode ? 'Save Changes' : 'Add Card',
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}