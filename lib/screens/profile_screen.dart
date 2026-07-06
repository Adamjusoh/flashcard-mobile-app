import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _userEmail = '';
  String _username = '';
  String _userRole = 'Loading...';
  bool _isLoading = true;
  int _deckCount = 0;
  int _cardCount = 0;
  int _daysSinceJoined = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? 'No email found';
      });

      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final createdAt = data['createdAt'] as Timestamp?;
          setState(() {
            _userRole = data['role'] ?? 'Student';
            _username = data['username'] ?? '';
            if (createdAt != null) {
              _daysSinceJoined = DateTime.now().difference(createdAt.toDate()).inDays;
            }
          });
        }

        // Fetch deck count
        final decksSnapshot = await _firestore
            .collection('decks')
            .where('authorId', isEqualTo: user.uid)
            .get();

        int totalCards = 0;
        for (var deck in decksSnapshot.docs) {
          final cardsSnapshot = await _firestore
              .collection('decks')
              .doc(deck.id)
              .collection('cards')
              .get();
          totalCards += cardsSnapshot.docs.length;
        }

        if (mounted) {
          setState(() {
            _deckCount = decksSnapshot.docs.length;
            _cardCount = totalCards;
          });
        }
      } catch (e) {
        setState(() {
          _userRole = 'Error fetching role';
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Gradient profile header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Gradient ring avatar
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF43F5E), Color(0xFFF59E0B), Color(0xFF10B981)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: const Color(0xFF6366F1),
                              child: Text(
                                _userEmail.isNotEmpty ? _userEmail[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _username.isNotEmpty ? '@$_username' : _userEmail,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _userRole,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stats row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _buildStatItem('$_deckCount', 'Decks', const Color(0xFF6366F1)),
                            _buildStatDivider(),
                            _buildStatItem('$_cardCount', 'Cards', const Color(0xFF8B5CF6)),
                            _buildStatDivider(),
                            _buildStatItem('$_daysSinceJoined', 'Days', const Color(0xFFA78BFA)),
                          ],
                        ),
                      ),
                    ),

                    // Account section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _buildSectionLabel('Account'),
                          const SizedBox(height: 8),
                          _buildSettingsGroup([
                            _buildSettingsRow(
                              icon: Icons.email_outlined,
                              iconColor: const Color(0xFF3B82F6),
                              label: 'Email',
                              value: _userEmail,
                            ),
                            _buildSettingsRow(
                              icon: Icons.badge_outlined,
                              iconColor: const Color(0xFFF59E0B),
                              label: 'Role',
                              value: _userRole,
                              valueColor: _userRole == 'Educator'
                                  ? const Color(0xFFF59E0B)
                                  : _userRole == 'Admin'
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF6366F1),
                            ),
                          ]),
                          const SizedBox(height: 24),
                          _buildSectionLabel('Actions'),
                          const SizedBox(height: 8),
                          _buildSettingsGroup([
                            if (_userRole == 'Admin')
                              _buildSettingsRow(
                                icon: Icons.admin_panel_settings_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                label: 'Admin Dashboard',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                                  );
                                },
                              ),
                            _buildSettingsRow(
                              icon: Icons.logout_rounded,
                              iconColor: const Color(0xFFEF4444),
                              label: 'Log Out',
                              isDestructive: true,
                              onTap: _logout,
                            ),
                          ]),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 30,
      width: 1,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 52),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? value,
    Color? valueColor,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Colorful icon in tinted circle
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                ),
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? const Color(0xFF94A3B8),
                    fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
      ),
    );
  }
}