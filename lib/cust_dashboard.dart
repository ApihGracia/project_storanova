import 'package:flutter/material.dart';
import 'main.dart';
// StoraNovaNavBar is now available from main.dart
import 'cust_profile.dart';
// import 'package:provider/provider.dart';

void main() {
  // runApp(const MyApp());
  runApp(CustDashboard());
}

class CustDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Dashboard')),
      body: const Center(
        child: Text('Welcome to the Customer Dashboard!'),
      ),
    );
  }
}

class CustHomePage extends StatefulWidget {
  const CustHomePage({Key? key}) : super(key: key);

  @override
  _CustHomePageState createState() => _CustHomePageState();
}

class _CustHomePageState extends State<CustHomePage> {
  int _currentIndex = 2; // Start at "Home"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB4D4FF),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.network(
              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
              width: 50,
              height: 50,
            ),
            const SizedBox(width: 8),
            const Text(
              'StoraNova(Customer)',
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildServiceButton(
                    icon: Icons.book,
                    label: 'Campus Resource Booking',
                    onTap: () {},
                  ),
                  _buildServiceButton(
                    icon: Icons.headset_mic,
                    label: 'Student Services Center',
                    onTap: () {},
                  ),
                  _buildServiceButton(
                    icon: Icons.calendar_today,
                    label: 'Class Schedules',
                    onTap: () {},
                  ),
                  _buildServiceButton(
                    icon: Icons.list_alt,
                    label: 'Examination Result',
                    onTap: () {},
                  ),
                  _buildServiceButton(
                    icon: Icons.assignment,
                    label: 'Course Registration',
                    onTap: () {},
                  ),
                  _buildServiceButton(
                    icon: Icons.apps,
                    label: 'More',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Latest News',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildNewsCard(
                      imageUrl:
                          'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                    ),
                    _buildNewsCard(
                      imageUrl:
                          'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                    ),
                    _buildNewsCard(
                      imageUrl:
                          'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Latest News',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildNewsCard(
                      imageUrl:
                          'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                    ),
                    _buildNewsCard(
                      imageUrl:
                          'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                    ),
                    _buildNewsCard(
                      imageUrl:
                          'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: StoraNovaNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
          if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          } else if (index == 2) {
            // Already on dashboard, do nothing
          }
          // Add navigation for other tabs as needed
        },
      ),
    );
  }

  Widget _buildServiceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard({required String imageUrl}) {
    return Card(
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}