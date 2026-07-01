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

  // The clean Bottom Sheet for the '+' button
  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Hugs the content tightly
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Text(
                'Create',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildBottomSheetOption(
                icon: Icons.style_outlined,
                title: 'New Deck',
                subtitle: 'Create a brand new stack of flashcards',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditDeckScreen()));
                },
              ),
              const SizedBox(height: 8),
              _buildBottomSheetOption(
                icon: Icons.add_card_outlined,
                title: 'Add Card to Existing',
                subtitle: 'Quickly add a card to a current deck',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Open a deck in your Library to add cards to it.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // Helper widget for the bottom sheet options
  Widget _buildBottomSheetOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF4F46E5), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Clean FAB for create action
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptions(context),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Clean Material Bottom Navigation Bar
      bottomNavigationBar: BottomAppBar(
        height: 68,
        padding: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', index: 0),
            _buildNavItem(icon: Icons.qr_code_scanner_outlined, activeIcon: Icons.qr_code_scanner_rounded, label: 'Scan', index: 1),
            const SizedBox(width: 48), // Space for the FAB
            _buildNavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: 'Explore', index: 2),
            _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required IconData activeIcon, required String label, required int index}) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}