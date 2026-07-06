import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'qr_scanner_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'add_edit_deck_screen.dart';

class MainTabController extends StatefulWidget {
  const MainTabController({super.key});

  @override
  State<MainTabController> createState() => _MainTabControllerState();
}

class _MainTabControllerState extends State<MainTabController> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabController.forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

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
      // Gradient FAB with bounce animation
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
        child: Container(
          height: 58,
          width: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(29),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditDeckScreen()),
                );
              },
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Vibrant bottom navigation bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', index: 0),
                _buildNavItem(icon: Icons.qr_code_scanner_outlined, activeIcon: Icons.qr_code_scanner_rounded, label: 'Scan', index: 1),
                const SizedBox(width: 56), // Space for the FAB
                _buildNavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: 'Explore', index: 2),
                _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile', index: 3),
              ],
            ),
          ),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 8, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF6366F1).withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                size: 22,
                color: isActive ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}