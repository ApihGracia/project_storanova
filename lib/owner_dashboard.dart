import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StoraNova App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFB4D4FF),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
              'StoraNova(owner)',
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
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
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
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