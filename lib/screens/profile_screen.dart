import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _userEmail = '';
  String _username = '';
  String _userRole = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  // Fetch the current user's email from Auth, and role from Firestore
  Future<void> _fetchUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? 'No email found';
      });

      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _userRole = userDoc.data()?['role'] ?? 'Student';
            _username = userDoc.data()?['username'] ?? '';
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

  // Handle Logout (Requirement 1: Authentication lifecycle)
  Future<void> _logout() async {
    // Show a confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Color(0xFFDC2626))),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          // Avatar & user info section
                          _buildUserInfoSection(),
                          const SizedBox(height: 28),
                          // Account section
                          _buildSectionLabel('Account'),
                          const SizedBox(height: 8),
                          _buildSettingsGroup([
                            _buildSettingsRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: _userEmail,
                            ),
                            _buildSettingsRow(
                              icon: Icons.badge_outlined,
                              label: 'Role',
                              value: _userRole,
                              valueColor: _userRole == 'Educator'
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF4F46E5),
                            ),
                          ]),
                          const SizedBox(height: 28),
                          // Actions section
                          _buildSectionLabel('Actions'),
                          const SizedBox(height: 8),
                          _buildSettingsGroup([
                            _buildSettingsRow(
                              icon: Icons.logout_rounded,
                              label: 'Log Out',
                              valueColor: const Color(0xFFDC2626),
                              isDestructive: true,
                              onTap: _logout,
                            ),
                          ]),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 42,
          backgroundColor: const Color(0xFF4F46E5),
          child: Text(
            _userEmail.isNotEmpty ? _userEmail[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Username
        Text(
          _username.isNotEmpty ? '@$_username' : _userEmail,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        // Role Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _userRole == 'Educator'
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _userRole,
            style: TextStyle(
              color: _userRole == 'Educator'
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF4F46E5),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 52),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
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
            Icon(
              icon,
              size: 20,
              color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                ),
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? const Color(0xFF64748B),
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