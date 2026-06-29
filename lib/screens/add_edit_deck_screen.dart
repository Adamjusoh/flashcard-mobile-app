import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddEditDeckScreen extends StatefulWidget {
  // If deckId is provided, the screen acts in "Edit" mode.
  // If deckId is null, it acts in "Create" mode.
  final String? deckId;
  final String? initialTitle;
  final bool? initialIsPublic;

  const AddEditDeckScreen({
    Key? key,
    this.deckId,
    this.initialTitle,
    this.initialIsPublic,
  }) : super(key: key);

  @override
  _AddEditDeckScreenState createState() => _AddEditDeckScreenState();
}

class _AddEditDeckScreenState extends State<AddEditDeckScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  
  bool _isPublic = false;
  bool _isLoading = false;
  String _userRole = 'Student'; // Default assumption

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if we are in Edit Mode
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialIsPublic != null) {
      _isPublic = widget.initialIsPublic!;
    }
    
    _fetchUserRole();
  }

  // 1. Fetch User Role to Determine UI Permissions (Requirement 4)
  Future<void> _fetchUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      setState(() {
        _userRole = userDoc.data()?['role'] ?? 'Student';
      });
    }
  }

  // 2. The Core CRUD Logic: Create and Update (Requirement 5)
  Future<void> _saveDeck() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final firestore = FirebaseFirestore.instance;

    try {
      if (widget.deckId == null) {
        // CREATE MODE
        await firestore.collection('decks').add({
          'title': _titleController.text.trim(),
          'authorId': uid,
          'isPublic': _isPublic, // True only if Educator flipped the switch
          'createdAt': Timestamp.now(),
        });
      } else {
        // UPDATE MODE
        await firestore.collection('decks').doc(widget.deckId).update({
          'title': _titleController.text.trim(),
          'isPublic': _isPublic,
        });
      }

      // Success, pop the screen
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.deckId == null ? 'Deck created!' : 'Deck updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving deck: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditMode = widget.deckId != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isEditMode ? 'Edit Deck' : 'Create New Deck',
          style: const TextStyle(color: Colors.white),
        ),
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              // 3. The Glassmorphic Form Card
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
                          const Icon(Icons.style, size: 60, color: Colors.white),
                          const SizedBox(height: 20),
                          
                          // Deck Title Field
                          TextFormField(
                            controller: _titleController,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                            decoration: InputDecoration(
                              labelText: 'Deck Title',
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
                                return 'Please enter a title for your deck.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 30),

                          // 4. Role-Based UI Element
                          if (_userRole == 'Educator')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Public Deck', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                        Text('Allow students to scan and copy this deck.', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _isPublic,
                                    activeColor: const Color(0xFF1BFFFF),
                                    onChanged: (val) {
                                      setState(() => _isPublic = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          
                          if (_userRole == 'Educator') const SizedBox(height: 30),

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
                                    onPressed: _saveDeck,
                                    child: Text(
                                      isEditMode ? 'SAVE CHANGES' : 'CREATE DECK',
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