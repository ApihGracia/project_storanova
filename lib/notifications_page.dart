import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database.dart';
import 'shared_widgets.dart';

class NotificationsPage extends StatefulWidget {
  final String? expectedRole; // Optional hint about user role
  
  const NotificationsPage({Key? key, this.expectedRole}) : super(key: key);
  
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isBanned = false;
  String _userRole = 'customer'; // Will be updated based on expectedRole or detection

  @override
  void initState() {
    super.initState();
    // Use the expected role hint if provided
    if (widget.expectedRole != null) {
      _userRole = widget.expectedRole!;
    }
    _detectUserRole(); // Detect role to confirm/correct
    _loadNotifications();
    _checkBanStatus();
  }

  Future<void> _detectUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Check if user is admin
      if (user.email == 'admin@storanova.com') {
        setState(() => _userRole = 'admin');
        return;
      }
      
      // First try to get username from display name
      String? username = user.displayName;
      if (username != null && username.isNotEmpty) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('AppUsers')
            .doc(username)
            .get();
        
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() => _userRole = data['role']?.toString().toLowerCase() ?? 'customer');
          return;
        }
      }
      
      // Fallback: check by email
      final query = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() => _userRole = data['role']?.toString().toLowerCase() ?? 'customer');
      }
    } catch (e) {
      // Default to customer on error - no need to change since it's already customer
    }
  }

  Future<String?> _getUsernameFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    // Try to get username from AppUsers by email
    if (user.email != null && user.email!.isNotEmpty) {
      final query = await FirebaseFirestore.instance.collection('AppUsers').where('email', isEqualTo: user.email).limit(1).get();
      if (query.docs.isNotEmpty) {
        // Return the document ID which should be the username
        return query.docs.first.id;
      }
    }
    
    // Fallback to displayName if available
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName;
    }
    
    return null;
  }

  Future<void> _checkBanStatus() async {
    final username = await _getUsernameFromFirestore();
    if (username == null) return;

    try {
      final userDoc = await _db.getUserByUsername(username);
      if (userDoc != null && userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        setState(() {
          _isBanned = userData?['isBanned'] ?? false;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final username = await _getUsernameFromFirestore();
    if (username == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final notifications = await _db.getUserNotifications(username);
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notifications: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget appBar;
    Widget? drawer;
    Widget? bottomNavBar;
    
    // Choose appropriate navigation based on user role
    switch (_userRole.toLowerCase()) {
      case 'admin':
        appBar = AdminAppBar(title: 'Notifications');
        drawer = AdminDrawer();
        bottomNavBar = AdminNavBar(
          currentIndex: 0, // Notifications is typically index 0 for admin
          onTap: (index) {
            // Navigation handled by shared widget
          },
        );
        break;
      case 'owner':
        appBar = OwnerAppBar(title: 'Notifications');
        drawer = OwnerDrawer();
        bottomNavBar = OwnerNavBar(
          currentIndex: 1, // Notifications is index 1 for owner
          onTap: (index) {
            // Navigation handled by shared widget
          },
        );
        break;
      default: // customer
        appBar = CustomerAppBar(title: 'Notifications');
        drawer = CustomerDrawer();
        bottomNavBar = CustomerNavBar(
          currentIndex: 2, // Notifications is index 2 for customer
          onTap: (index) {
            // Navigation handled by shared widget
          },
        );
        break;
    }
    
    return Scaffold(
      appBar: appBar as PreferredSizeWidget,
      endDrawer: drawer,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_isBanned) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Your Account is Banned',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your account has been suspended. You can only access notifications. Please check the messages below for more information.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: _notifications.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No notifications',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            return NotificationCard(
                              notification: notification,
                              onMarkAsRead: _markAsRead,
                              onAppeal: _handleAppeal,
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: bottomNavBar,
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _db.markNotificationAsRead(notificationId);
      _loadNotifications(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notification as read: $e')),
      );
    }
  }

  Future<void> _handleAppeal(Map<String, dynamic> notification) async {
    final username = await _getUsernameFromFirestore();
    if (username == null) return;

    // Check if this is a ban notification that can be appealed
    if (notification['type'] != 'ban') return;

    // Check if user already has a pending appeal
    final existingAppeals = await _db.getAllAppeals(status: 'pending');
    final hasExistingAppeal = existingAppeals.any((appeal) => appeal['username'] == username);
    
    if (hasExistingAppeal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have a pending appeal.')),
      );
      return;
    }

    // Determine ban type based on notification message or check user/house ban status
    String banType = 'user'; // default
    final userDoc = await _db.getUserByUsername(username);
    if (userDoc != null && userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>?;
      final isUserBanned = userData?['isBanned'] ?? false;
      final isHouseBanned = userData?['isHouseBanned'] ?? false;
      
      if (isHouseBanned && !isUserBanned) {
        banType = 'house';
      } else if (isUserBanned) {
        banType = 'user';
      }
    }

    _showAppealDialog(username, notification, banType);
  }

  void _showAppealDialog(String username, Map<String, dynamic> notification, String banType) {
    final TextEditingController appealController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Appeal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ban Type: ${banType.toUpperCase()}'),
            const SizedBox(height: 8),
            Text('Original ban reason: ${notification['message']}'),
            const SizedBox(height: 16),
            Text('Please explain why you believe this ${banType} ban should be lifted:'),
            const SizedBox(height: 8),
            TextField(
              controller: appealController,
              decoration: const InputDecoration(
                hintText: 'Enter your appeal reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (appealController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an appeal reason.')),
                );
                return;
              }

              try {
                await _db.submitAppeal(
                  username: username,
                  appealReason: appealController.text.trim(),
                  banType: banType,
                );
                
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appeal submitted successfully!')),
                );
                _loadNotifications(); // Refresh notifications
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error submitting appeal: $e')),
                );
              }
            },
            child: const Text('Submit Appeal'),
          ),
        ],
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final Function(String) onMarkAsRead;
  final Function(Map<String, dynamic>) onAppeal;

  const NotificationCard({
    Key? key,
    required this.notification,
    required this.onMarkAsRead,
    required this.onAppeal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] ?? false;
    final type = notification['type'] as String;
    final createdAt = DateTime.parse(notification['createdAt']);
    
    Color backgroundColor;
    Color borderColor;
    IconData icon;
    
    switch (type) {
      case 'ban':
        backgroundColor = Colors.red.withOpacity(0.1);
        borderColor = Colors.red;
        icon = Icons.block;
        break;
      case 'warning':
        backgroundColor = Colors.orange.withOpacity(0.1);
        borderColor = Colors.orange;
        icon = Icons.warning;
        break;
      case 'appeal':
        backgroundColor = Colors.blue.withOpacity(0.1);
        borderColor = Colors.blue;
        icon = Icons.gavel;
        break;
      default:
        backgroundColor = Colors.blue.withOpacity(0.1);
        borderColor = Colors.blue;
        icon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isRead ? Colors.grey.withOpacity(0.1) : backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isRead ? Colors.grey : borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: isRead ? Colors.grey : borderColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notification['title'] ?? 'Notification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isRead ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                notification['message'] ?? '',
                style: TextStyle(
                  color: isRead ? Colors.grey : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Row(
                    children: [
                      if (type == 'ban' && !isRead)
                        TextButton(
                          onPressed: () => onAppeal(notification),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                          child: const Text('Appeal'),
                        ),
                      if (!isRead)
                        TextButton(
                          onPressed: () => onMarkAsRead(notification['id']),
                          child: const Text('Mark as Read'),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
