import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database.dart';
import 'shared_widgets.dart';
import 'main.dart';

class AccountPage extends StatefulWidget {
  final String userRole; // 'customer' or 'owner'
  
  const AccountPage({Key? key, required this.userRole}) : super(key: key);
  
  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get username from email
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isNotEmpty) {
        _username = usersSnapshot.docs.first.id;
        final userDoc = await _db.getUserByUsername(_username!);
        
        if (userDoc != null && userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading account data: $e')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete your account?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('This action will:'),
            SizedBox(height: 8),
            Text('• Delete all your personal data'),
            Text('• Cancel all pending bookings'),
            Text('• Remove your account permanently'),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Deleting account...'),
              ],
            ),
          ),
        );

        // Delete user data from Firestore - Complete deletion from all collections
        if (_username != null) {
          // Use the comprehensive deletion function
          await _db.deleteUserCompletely(_username!);
        }

        // Delete Firebase Auth account
        await FirebaseAuth.instance.currentUser?.delete();

        // Navigate to login page
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        return 'N/A';
      }
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget appBar;
    
    // Choose appropriate navigation based on user role
    switch (widget.userRole.toLowerCase()) {
      case 'owner':
        appBar = OwnerAppBar(title: 'Account', showBackButton: true, showMenuIcon: false);
        break;
      default: // customer
        appBar = CustomerAppBar(title: 'Account', showBackButton: true, showMenuIcon: false);
        break;
    }

    return Scaffold(
      appBar: appBar as PreferredSizeWidget,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account Information Card
                  Card(
                    elevation: 2,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_circle,
                                size: 32,
                                color: Color(0xFF1976D2),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Account Information',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          if (_userData != null) ...[
                            _buildInfoRow('Username', _username ?? 'N/A'),
                            _buildInfoRow('Name', _userData!['name']?.toString() ?? 'N/A'),
                            _buildInfoRow('Email', _userData!['email']?.toString() ?? 'N/A'),
                            _buildInfoRow('Phone', _userData!['phone']?.toString() ?? 'N/A'),
                            _buildInfoRow('Role', _userData!['role']?.toString().toUpperCase() ?? 'N/A'),
                            _buildInfoRow('Date Joined', _formatDate(_userData!['createdAt'])),
                            
                            if (_userData!['address'] != null && _userData!['address'].toString().isNotEmpty)
                              _buildInfoRow('Address', _userData!['address'].toString()),
                          ] else ...[
                            const Center(
                              child: Text(
                                'Unable to load account information',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Danger Zone Card
                  Card(
                    elevation: 2,
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning,
                                size: 32,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Danger Zone',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Permanently delete your account and all associated data. This action cannot be undone.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _deleteAccount,
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Delete Account Permanently'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
