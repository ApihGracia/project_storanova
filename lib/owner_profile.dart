import 'package:flutter/material.dart';
import 'main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'owner_dashboard.dart';

void main() {
  runApp(const MyApp());
}

class ProfileData {
  ProfileData({
    required this.legalName,
    required this.role,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.emergencyContact,
  });

  final String legalName;
  final String role;
  final String phoneNumber;
  final String email;
  final String address;
  final String emergencyContact;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profile App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFADD8E6),
      ),
      home: const ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? name;
  String? role;
  String? phone;
  String? email;
  String? address;
  String? emergencyContact;
  bool isLoading = true;
  int _currentIndex = 4;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { isLoading = false; });
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('AppUsers').doc(user.displayName ?? user.email?.split('@')[0]).get();
    final data = doc.data();
    setState(() {
      name = data?['name'] ?? '';
      role = data?['role'] ?? '';
      phone = data?['phone'] ?? '';
      email = data?['email'] ?? user.email ?? '';
      address = data?['address'] ?? '';
      emergencyContact = data?['emergencyContact'] ?? '';
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFADD8E6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(name != null && name!.isNotEmpty ? name! : 'Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue,
                          width: 5,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _profileField('Name', name ?? ''),
                        _profileField('Role', role ?? ''),
                        _profileField('Phone Number', phone ?? ''),
                        _profileField('Email', email ?? ''),
                        _profileField('Address', address ?? ''),
                        _profileField('Emergency Contact', emergencyContact ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: StoraNovaNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
          if (index == 2) {
            // Home (dashboard)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => OwnerHomePage()),
            );
          } else if (index == 4) {
            // Already on profile
          }
          // Add navigation for other tabs as needed
        },
      ),
    );
  }
  Widget _profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(value.isNotEmpty ? value : '', style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// StoraNovaNavBar is now imported from main.dart


class ProfileRow extends StatelessWidget {
  const ProfileRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }
}