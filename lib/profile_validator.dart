import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'owner_dashboard.dart';
import 'cust_dashboard.dart';

class ProfileValidator {
  static Future<bool> isCustomerProfileComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Get username
    String? username = user.displayName;
    if (username == null || username.isEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (userDoc.docs.isNotEmpty) {
        username = userDoc.docs.first.id;
      } else {
        return false;
      }
    }

    final doc = await FirebaseFirestore.instance.collection('AppUsers').doc(username).get();
    final data = doc.data();
    if (data == null) return false;

    // Check required fields for customers: name and email
    final name = data['name']?.toString().trim() ?? '';
    final email = data['email']?.toString().trim() ?? '';
    final phone = data['phone']?.toString().trim() ?? '';

    return name.isNotEmpty && email.isNotEmpty && phone.isNotEmpty;
  }

  static Future<bool> isOwnerProfileComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Get username
    String? username = user.displayName;
    if (username == null || username.isEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (userDoc.docs.isNotEmpty) {
        username = userDoc.docs.first.id;
      } else {
        return false;
      }
    }

    final doc = await FirebaseFirestore.instance.collection('AppUsers').doc(username).get();
    final data = doc.data();
    if (data == null) return false;

    // Check required fields for owners: name, email, phone, and address
    final name = data['name']?.toString().trim() ?? '';
    final email = data['email']?.toString().trim() ?? '';
    final phone = data['phone']?.toString().trim() ?? '';
    final address = data['address']?.toString().trim() ?? '';

    return name.isNotEmpty && email.isNotEmpty && phone.isNotEmpty && address.isNotEmpty;
  }

  static void showProfileIncompleteDialog(BuildContext context, {required bool isOwner}) {
    final action = isOwner ? 'register a house' : 'make a booking';
    final requiredFields = isOwner 
        ? 'name, email, phone number, and address'
        : 'name, email, and phone number';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(
            color: Color(0xFF1976D2),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'To $action, you need to complete your profile first. Please fill in all required fields: $requiredFields.',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to profile page
              _navigateToProfile(context, isOwner: isOwner);
            },
            child: const Text('Go to Profile'),
          ),
        ],
      ),
    );
  }

  static void _navigateToProfile(BuildContext context, {required bool isOwner}) {
    if (isOwner) {
      // Navigate to owner dashboard with profile tab selected (index 3)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const OwnerHomePage(initialTabIndex: 3),
        ),
        (route) => false,
      );
    } else {
      // Navigate to customer dashboard with profile tab selected (index 3)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const CustHomePage(initialTabIndex: 3),
        ),
        (route) => false,
      );
    }
  }
}
