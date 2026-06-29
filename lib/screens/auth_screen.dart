import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLogin = true;
  bool _isLoading = false;

  String _email = '';
  String _password = '';
  String _role = 'Student'; // Default role

  // Form Submission Logic & Error Handling (Requirement 1 & 2)
  void _submitAuthForm() async {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus(); // Close keyboard

    if (!isValid) return;

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // LOGIN MODE
        await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        // Navigation to MainTabController happens here
      } else {
        // REGISTER MODE
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // Save User Role to Firestore Database (Requirement 3 & 4)
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': _email,
          'role': _role,
          'createdAt': Timestamp.now(),
        });
      }
    } on FirebaseAuthException catch (err) {
      // Firebase Error Handling
      var message = 'An error occurred, please check your credentials!';
      if (err.message != null) {
        message = err.message!;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (err) {
      print(err);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App branding
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recall',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Smart Flashcards',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 40),

                // Auth Card
                Card(
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isLogin ? 'Welcome Back' : 'Create Account',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLogin
                                ? 'Sign in to continue studying'
                                : 'Get started with Recall',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Email Field with Validation
                          TextFormField(
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty || !value.contains('@')) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                            onSaved: (value) => _email = value!,
                          ),
                          const SizedBox(height: 16),

                          // Password Field with Validation
                          TextFormField(
                            style: const TextStyle(color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, size: 20),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty || value.length < 7) {
                                return 'Password must be at least 7 characters long.';
                              }
                              return null;
                            },
                            onSaved: (value) => _password = value!,
                          ),
                          const SizedBox(height: 16),

                          // Role Selection (Only visible during Registration)
                          if (!_isLogin)
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'I am a...',
                                prefixIcon: Icon(Icons.person_outline, size: 20),
                              ),
                              value: _role,
                              items: ['Student', 'Educator'].map((String role) {
                                return DropdownMenuItem(
                                  value: role,
                                  child: Text(role),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _role = value!),
                            ),

                          const SizedBox(height: 28),

                          // Submit Button
                          if (_isLoading)
                            const Center(
                              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                            )
                          else
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _submitAuthForm,
                                child: Text(_isLogin ? 'Sign In' : 'Create Account'),
                              ),
                            ),

                          const SizedBox(height: 12),

                          // Toggle Mode Button
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            child: Text(
                              _isLogin ? 'Create new account' : 'I already have an account',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}