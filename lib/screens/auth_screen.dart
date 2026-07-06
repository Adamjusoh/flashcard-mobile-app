import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLogin = true;
  bool _isLoading = false;

  String _email = '';
  String _password = '';
  String _username = '';
  String _role = 'Student'; // Default role

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _animController.reverse().then((_) {
      setState(() => _isLogin = !_isLogin);
      _animController.forward();
    });
  }

  // Form Submission Logic & Error Handling
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
      } else {
        // REGISTER MODE
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // Save User Role and Username to Firestore Database
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': _email,
          'username': _username,
          'role': _role,
          'createdAt': Timestamp.now(),
        });
      }
    } on FirebaseAuthException catch (err) {
      var message = 'An error occurred, please check your credentials!';
      if (err.code == 'invalid-credential' || 
          err.code == 'wrong-password' || 
          err.code == 'user-not-found' ||
          (err.message?.contains('auth credential is incorrect, malformed or has expired') ?? false)) {
        message = 'Wrong email or password';
      } else if (err.message != null) {
        message = err.message!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (err) {
      // Ignored
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background top half
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -30,
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      // App branding
                      Container(
                        height: 76,
                        width: 76,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.view_carousel_rounded, size: 42, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Recall',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Smart Flashcards',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Frosted glass auth card
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1,
                                ),
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
                                      const SizedBox(height: 6),
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
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter a password.';
                                          }
                                          if (!_isLogin) {
                                            if (value.length < 8) {
                                              return 'Password must be at least 8 characters long.';
                                            }
                                            if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                              return 'Password must contain at least 1 uppercase letter.';
                                            }
                                            if (!RegExp(r'[0-9]').hasMatch(value)) {
                                              return 'Password must contain at least 1 number.';
                                            }
                                            if (!RegExp(r'[!@#\$%\^&\*(),.?":{}|<>]').hasMatch(value)) {
                                              return 'Password must contain at least 1 special character.';
                                            }
                                          }
                                          return null;
                                        },
                                        onSaved: (value) => _password = value!,
                                      ),
                                      const SizedBox(height: 16),

                                      // Username Field (Only visible during Registration)
                                      if (!_isLogin)
                                        TextFormField(
                                          style: const TextStyle(color: Color(0xFF0F172A)),
                                          decoration: const InputDecoration(
                                            labelText: 'Username',
                                            prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                                          ),
                                          validator: (value) {
                                            if (!_isLogin) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Please enter a username.';
                                              }
                                              if (value.trim().length < 3) {
                                                return 'Username must be at least 3 characters.';
                                              }
                                              if (value.contains(' ')) {
                                                return 'Username cannot contain spaces.';
                                              }
                                            }
                                            return null;
                                          },
                                          onSaved: (value) => _username = value?.trim() ?? '',
                                        ),

                                      if (!_isLogin)
                                        const SizedBox(height: 16),

                                      // Role Selection (Only visible during Registration)
                                      if (!_isLogin)
                                        DropdownButtonFormField<String>(
                                          decoration: const InputDecoration(
                                            labelText: 'I am a...',
                                            prefixIcon: Icon(Icons.person_outline, size: 20),
                                          ),
                                          initialValue: _role,
                                          items: ['Student', 'Educator'].map((String role) {
                                            return DropdownMenuItem(
                                              value: role,
                                              child: Text(role),
                                            );
                                          }).toList(),
                                          onChanged: (value) => setState(() => _role = value!),
                                        ),

                                      const SizedBox(height: 28),

                                      // Submit Button with gradient
                                      if (_isLoading)
                                        const Center(
                                          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                                        )
                                      else
                                        Container(
                                          height: 52,
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
                                              onTap: _submitAuthForm,
                                              child: Center(
                                                child: Text(
                                                  _isLogin ? 'Sign In' : 'Create Account',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                      const SizedBox(height: 12),

                                      // Toggle Mode Button
                                      TextButton(
                                        onPressed: _toggleMode,
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
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}