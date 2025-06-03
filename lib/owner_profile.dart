import 'package:flutter/material.dart';

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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileData = ProfileData(
      legalName: 'Che Hee In',
      role: 'Owner',
      phoneNumber: '+60198765432',
      email: 'chaheein202@gmail.com',
      address: 'Taman Bernam Jaya',
      emergencyContact: '+604455667788',
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFADD8E6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {},
        ),
        title: const Text('Profile (owner)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
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
          Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ProfileRow(label: 'Legal Name', value: profileData.legalName),
                  ProfileRow(label: 'Role', value: profileData.role),
                  ProfileRow(label: 'Phone Number', value: profileData.phoneNumber),
                  ProfileRow(label: 'Email', value: profileData.email),
                  ProfileRow(label: 'Address', value: profileData.address),
                  ProfileRow(label: 'Emergency Contact', value: profileData.emergencyContact),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFADD8E6),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Notification',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

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