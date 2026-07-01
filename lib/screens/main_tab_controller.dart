import 'package:flutter/material.dart';

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

  // The screens are dynamically generated so QRScannerScreen knows when it's active
  List<Widget> get _screens => [
    const HomeScreen(),
    QRScannerScreen(
      isActive: _currentIndex == 1,
      onScanSuccess: () {
        setState(() {
          _currentIndex = 0; // Redirect to Home tab on success
        });
      },
    ),
    const CommunityScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Clean FAB for direct deck creation
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditDeckScreen()),
          );
        },
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Clean Bottom Navigation Bar
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