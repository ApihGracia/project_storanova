import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database.dart';
import 'shared_widgets.dart';
import 'main.dart';

class AccountPage extends StatefulWidget {
  final String userRole;
  const AccountPage({Key? key, required this.userRole}) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isDeleting = false;
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

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isNotEmpty) {
        _username = usersSnapshot.docs.first.id;
        final userDoc = await _db.getUserByUsername(_username!);

        if (userDoc != null && userDoc.exists) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _userData = userDoc.data() as Map<String, dynamic>;
                _isLoading = false;
              });
            }
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading account data: $e')),
        );
      });
    }
  }

  Future<String?> _showPasswordDialog() async {
    final TextEditingController passwordController = TextEditingController();
    String? result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-authenticate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('For security, please enter your password to delete your account:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter your password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    return result;
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to permanently delete your account?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('This action will:'),
              SizedBox(height: 8),
              Text('• Delete all your personal data'),
              Text('• Cancel all pending bookings'),
              Text('• Remove your account permanently'),
              SizedBox(height: 12),
              Text('This action cannot be undone!',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user logged in'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final password = await _showPasswordDialog();
      if (password == null || password.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password required for account deletion'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (mounted) setState(() { _isDeleting = true; });
      bool deletionSuccess = false;
      String? errorMessage;
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        if (_username != null) {
          await _db.deleteUserCompletely(_username!);
        }
        await user.delete();
        deletionSuccess = true;
      } catch (e) {
        errorMessage = e.toString();
      }
      if (mounted) setState(() { _isDeleting = false; });
      if (deletionSuccess && mounted) {
        Future.microtask(() {
          if (mounted) {
            Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
            Future.microtask(() {
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            });
          }
        });
      } else if (errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $errorMessage'), backgroundColor: Colors.red),
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
            child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 14)),
          ),
          const Text(': ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget appBar;
    switch (widget.userRole.toLowerCase()) {
      case 'owner':
        appBar = OwnerAppBar(title: 'Account', showBackButton: true, showMenuIcon: false);
        break;
      default:
        appBar = CustomerAppBar(title: 'Account', showBackButton: true, showMenuIcon: false);
        break;
    }

    return Scaffold(
      appBar: appBar as PreferredSizeWidget,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.account_circle, size: 32, color: Color(0xFF1976D2)),
                                SizedBox(width: 12),
                                Text('Account Information',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                              const Center(child: Text('Unable to load account information', style: TextStyle(color: Colors.grey))),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                                Icon(Icons.warning, size: 32, color: Colors.red.shade700),
                                const SizedBox(width: 12),
                                Text('Danger Zone',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Permanently delete your account and all associated data. This action cannot be undone.',
                              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                          _isDeleting
                              ? const Center(child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: CircularProgressIndicator(),
                                ))
                              : SizedBox(
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
      ),
    );
  }
}
