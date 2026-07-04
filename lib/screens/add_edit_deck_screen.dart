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
    super.key,
    this.deckId,
    this.initialTitle,
    this.initialIsPublic,
  });

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
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving deck: $e'),
            backgroundColor: const Color(0xFFDC2626),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: Text(
          isEditMode ? 'Edit Deck' : 'Create New Deck',
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
              // Deck Title Field
              const Text(
                'Deck Title',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'e.g., Biology Chapter 5',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title for your deck.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Role-Based UI Element
              if (_userRole == 'Educator') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Public Deck',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Allow students to scan and copy this deck.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _isPublic,
                        activeTrackColor: const Color(0xFF4F46E5),
                        onChanged: (val) {
                          setState(() => _isPublic = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Save Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                  : SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveDeck,
                        child: Text(
                          isEditMode ? 'Save Changes' : 'Create Deck',
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