import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// Import your screens
import 'screens/auth_screen.dart';
import 'screens/main_tab_controller.dart';



void main() async {
  // Ensure that Flutter bindings are initialized before calling Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (This connects your app to the cloud)
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  runApp(const RecallApp());
}

class RecallApp extends StatelessWidget {
  const RecallApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recall - Smart Flashcards',
      debugShowCheckedModeBanner: false, // Removes the red 'DEBUG' banner

      // Set a default theme that matches our Glassmorphism aesthetic
      theme: ThemeData(
        primaryColor: const Color(0xFF1BFFFF),
        scaffoldBackgroundColor: const Color(0xFF2E3192),
        fontFamily: 'Roboto', // You can change this to any Google Font
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFF1BFFFF), // Accent color
        ),
      ),

      // The StreamBuilder listens to the user's login state in real-time
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. If the app is still checking Firebase, show a loading spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF2E3192),
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          // 2. If the snapshot has data, the user is logged in!
          if (snapshot.hasData) {
            return const MainTabController();
          }

          // 3. Otherwise, the user is NOT logged in. Show the Auth Screen.
          return const AuthScreen();
        },
      ),
    );
  }
}