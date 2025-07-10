import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'cust_booking_history.dart';
import 'database.dart';

// Common logout method
Future<void> performLogout(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const LoginPage()),
    (route) => false,
  );
}

// Helper function to get username from Firestore
Future<String?> _getUsernameFromFirestore() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  
  final usersSnapshot = await FirebaseFirestore.instance
      .collection('AppUsers')
      .where('email', isEqualTo: user.email)
      .limit(1)
      .get();
  
  if (usersSnapshot.docs.isNotEmpty) {
    return usersSnapshot.docs.first.id;
  }
  
  return null;
}

// Notification Counter Widget
class NotificationCounter extends StatefulWidget {
  const NotificationCounter({Key? key}) : super(key: key);

  @override
  State<NotificationCounter> createState() => _NotificationCounterState();
}

class _NotificationCounterState extends State<NotificationCounter> {
  final DatabaseService _db = DatabaseService();
  int _notificationCount = 0;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadNotificationCount();
  }

  @override
  void didUpdateWidget(NotificationCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh the count when widget updates
    _loadNotificationCount();
  }

  Future<void> _loadNotificationCount() async {
    try {
      _username = await _getUsernameFromFirestore();
      if (_username != null) {
        final count = await _db.getUnreadNotificationCount(_username!);
        if (mounted) {
          setState(() {
            _notificationCount = count;
          });
        }
      }
    } catch (e) {
      print('Error loading notification count: $e');
    }
  }

  // Method to refresh count (can be called from external widgets)
  void refreshCount() {
    _loadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Icon(Icons.notifications),
        if (_notificationCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _notificationCount > 99 ? '99+' : _notificationCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// Customer App Bar
class CustomerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showMenuIcon;

  const CustomerAppBar({
    Key? key,
    required this.title,
    this.showBackButton = false,
    this.showMenuIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBackButton,
      backgroundColor: const Color(0xFF1976D2), // Darker blue
      foregroundColor: Colors.white,
      elevation: 2,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      centerTitle: true,
      actions: showMenuIcon ? [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
            },
          ),
        ),
      ] : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Customer Drawer
class CustomerDrawer extends StatelessWidget {
  const CustomerDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF1976D2), // Darker blue to match admin
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text for contrast
                ),
              ),
            ),
            const SizedBox(height: 32), // Add some spacing instead of Spacer
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Booking History'),
              onTap: () {
                Navigator.pop(context); // Close drawer first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustBookingHistory(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
              onTap: () => performLogout(context),
            ),
            const Spacer(), // Keep remaining space at bottom
          ],
        ),
      ),
    );
  }
}

// Customer Navigation Bar
class CustomerNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomerNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: const Color(0xFF1976D2), // Darker blue
      selectedItemColor: const Color(0xFF0D47A1), // Dark blue for selected
      unselectedItemColor: const Color(0xFFBBDEFB), // Light blue for unselected
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: 'Wishlist',
        ),
        BottomNavigationBarItem(
          icon: NotificationCounter(),
          label: 'Notifications',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

// Owner App Bar
class OwnerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;

  const OwnerAppBar({
    Key? key,
    required this.title,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBackButton,
      backgroundColor: const Color(0xFF1976D2), // Darker blue
      foregroundColor: Colors.white,
      elevation: 2,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      centerTitle: true,
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
            },
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Owner Drawer
class OwnerDrawer extends StatelessWidget {
  const OwnerDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF1976D2), // Darker blue to match admin
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text for contrast
                ),
              ),
            ),
            const SizedBox(height: 32), // Add some spacing instead of Spacer
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
              onTap: () => performLogout(context),
            ),
            const Spacer(), // Keep remaining space at bottom
          ],
        ),
      ),
    );
  }
}

// Owner Navigation Bar
class OwnerNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const OwnerNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: const Color(0xFF1976D2), // Darker blue
      selectedItemColor: const Color(0xFF0D47A1), // Dark blue for selected
      unselectedItemColor: const Color(0xFFBBDEFB), // Light blue
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Customers',
        ),
        BottomNavigationBarItem(
          icon: NotificationCounter(),
          label: 'Notifications',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

// Admin App Bar
class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;

  const AdminAppBar({
    Key? key,
    required this.title,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBackButton,
      title: Text(title),
      backgroundColor: const Color(0xFF1976D2), // Darker blue
      foregroundColor: Colors.white,
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
            },
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Admin Drawer
class AdminDrawer extends StatelessWidget {
  const AdminDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF1976D2), // Darker blue
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32), // Add some spacing instead of Spacer
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(color: Colors.red)),
              onTap: () => performLogout(context),
            ),
            const Spacer(), // Keep remaining space at bottom
          ],
        ),
      ),
    );
  }
}

// Admin Navigation Bar
class AdminNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AdminNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: const Color(0xFF1976D2), // Darker blue
      selectedItemColor: const Color(0xFF0D47A1), // Dark blue for selected
      unselectedItemColor: const Color(0xFFBBDEFB), // Light blue
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Applications',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Users',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.gavel),
          label: 'Appeals',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Statistics',
        ),
      ],
    );
  }
}
