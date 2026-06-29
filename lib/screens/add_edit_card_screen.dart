import 'dart:ui';
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving card: $e'),
            backgroundColor: Colors.redAccent,
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isEditMode ? 'Edit Card' : 'Add New Card',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              // 2. The Glassmorphic Form Card
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.library_books, size: 60, color: Colors.white),
                          const SizedBox(height: 20),
                          
                          // 3. FRONT TEXT FIELD (Question)
                          TextFormField(
                            controller: _frontController,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                            maxLines: 4, // Allows for longer questions
                            minLines: 1,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Front (Question)',
                              labelStyle: const TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter the front of the card.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // 4. BACK TEXT FIELD (Answer)
                          TextFormField(
                            controller: _backController,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                            maxLines: 5, // Answers are usually longer
                            minLines: 1,
                            decoration: InputDecoration(
                              labelText: 'Back (Answer)',
                              labelStyle: const TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter the back of the card.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 40),

                          // Save Button
                          _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF2E3192),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _saveCard,
                                    child: Text(
                                      isEditMode ? 'SAVE CHANGES' : 'ADD CARD',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}