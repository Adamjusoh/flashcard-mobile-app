import 'dart:ui';
import 'package:flutter/material.dart';

// Import all the screens we built so the tabs actually work
import 'home_screen.dart';
import 'qr_scanner_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'add_edit_deck_screen.dart';

class MainTabController extends StatefulWidget {
  const MainTabController({Key? key}) : super(key: key);

  @override
  _MainTabControllerState createState() => _MainTabControllerState();
}

class _MainTabControllerState extends State<MainTabController> {
  int _currentIndex = 0;

  // The actual screens replacing the placeholders
  final List<Widget> _screens = [
    const HomeScreen(),
    const QRScannerScreen(),
    const CommunityScreen(),
    const ProfileScreen(),
  ];

  // The Glassmorphic Bottom Sheet for the '+' button
  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Required for the blur effect to show
      isScrollControlled: true, // Allows the sheet to size itself properly
      useSafeArea: true, // Prevents awkward jumping around the system navigation bar
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                // Removed the harsh top border that was causing the white line
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Hugs the content tightly
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Smooth native-looking drag handle at the top
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildBottomSheetOption(
                    icon: Icons.style,
                    title: 'New Deck',
                    subtitle: 'Create a brand new stack of flashcards',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditDeckScreen()));
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildBottomSheetOption(
                    icon: Icons.add_to_photos,
                    title: 'Add Card to Existing',
                    subtitle: 'Quickly add a card to a current deck',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Open a deck in your Library to add cards to it.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Color(0xFF2E3192),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper widget for the bottom sheet options
  Widget _buildBottomSheetOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Crucial for letting the background gradient flow under the bar
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // NEW: Custom Floating Capsule (Pill) Navigation Bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20), // Floating effect
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40), // Pill Shape
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), // Made slightly brighter for visibility
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
                    _buildNavItem(icon: Icons.qr_code_scanner_rounded, label: 'Scan', index: 1),

                    // The glowing circle + button placed directly in the row
                    GestureDetector(
                      onTap: () => _showCreateOptions(context),
                      child: Container(
                        height: 52, // Slightly larger for better touch target
                        width: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1BFFFF).withOpacity(0.6),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        // The Material widget ensures crisp, anti-aliased borders on tablets
                        child: const Material(
                          type: MaterialType.circle,
                          color: Colors.white,
                          clipBehavior: Clip.antiAlias,
                          child: Icon(Icons.add, color: Color(0xFF2E3192), size: 30),
                        ),
                      ),
                    ),

                    _buildNavItem(icon: Icons.public_rounded, label: 'Explore', index: 2),
                    _buildNavItem(icon: Icons.person_rounded, label: 'Profile', index: 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28,
            color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}