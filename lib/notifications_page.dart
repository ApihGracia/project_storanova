import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database.dart';
import 'shared_widgets.dart';
import 'owner_dashboard.dart';
import 'cust_dashboard.dart';

class NotificationsPage extends StatefulWidget {
  final String? expectedRole; // Optional hint about user role
  final bool isEmbedded; // Whether this is embedded in another Scaffold
  
  const NotificationsPage({Key? key, this.expectedRole, this.isEmbedded = false}) : super(key: key);
  
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
      // Refresh the notification counter when notifications are loaded
      NotificationCounter.refreshGlobal();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notifications: $e')),
      );
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => NotificationDetailsDialog(
        notification: notification,
        onMarkAsRead: _markAsRead,
        onAppeal: _handleAppeal,
        userRole: _userRole,
        onDelete: _deleteNotification,
      ),
    );
  }
  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _db.deleteNotification(notificationId);
      _loadNotifications();
      // Refresh the notification counter globally
      NotificationCounter.refreshGlobal();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting notification: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If embedded, just return the content without Scaffold
    if (widget.isEmbedded) {
      return _buildNotificationContent();
    }
    
    // Otherwise, build the full page with navigation
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
          currentIndex: 2, // Notifications is index 2 for owner
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
      body: _buildNotificationContent(),
      bottomNavigationBar: bottomNavBar,
    );
  }

  Widget _buildNotificationContent() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
              children: [
                // Refresh button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadNotifications,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),
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
                          padding: EdgeInsets.zero,
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            return CompactNotificationCard(
                              notification: notification,
                              onTap: () => _showNotificationDetails(notification),
                            );
                          },
                        ),
                ),
              ],
            );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _db.markNotificationAsRead(notificationId);
      _loadNotifications(); // Refresh the list
      // Refresh the notification counter globally
      NotificationCounter.refreshGlobal();
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
                
                // Automatically mark the notification as read
                await _markAsRead(notification['id']);
                
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

// Compact notification card for the list view
class CompactNotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const CompactNotificationCard({
    Key? key,
    required this.notification,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] ?? false;
    final type = notification['type'] as String;
    final createdAt = DatabaseService.parseDateTime(notification['createdAt']);
    
    Color iconColor;
    IconData icon;
    
    switch (type) {
      case 'ban':
        iconColor = Colors.red;
        icon = Icons.block;
        break;
      case 'warning':
        iconColor = Colors.orange;
        icon = Icons.warning;
        break;
      case 'appeal':
        iconColor = Colors.blue;
        icon = Icons.gavel;
        break;
      case 'booking':
        iconColor = Colors.green;
        icon = Icons.calendar_today;
        break;
      default:
        iconColor = Colors.blue;
        icon = Icons.info;
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon section
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isRead ? Colors.grey : iconColor).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isRead ? Colors.grey : iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and time row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                                  color: isRead ? Colors.grey[600] : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateCompact(createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Message
                        Text(
                          notification['message'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: isRead ? Colors.grey[600] : Colors.grey[700],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status indicator and arrow
                  Column(
                    children: [
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: iconColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Line separator
          Container(
            height: 1,
            color: Colors.grey[200],
            margin: const EdgeInsets.only(left: 68), // Align with content, not icon
          ),
        ],
      ),
    );
  }

  String _formatDateCompact(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// Full notification details dialog
class NotificationDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> notification;
  final Function(String) onMarkAsRead;
  final Function(Map<String, dynamic>) onAppeal;
  final String userRole;
  final Function(String) onDelete;

  const NotificationDetailsDialog({
    Key? key,
    required this.notification,
    required this.onMarkAsRead,
    required this.onAppeal,
    required this.userRole,
    required this.onDelete,
  }) : super(key: key);

  @override
  _NotificationDetailsDialogState createState() => _NotificationDetailsDialogState();
}

class _NotificationDetailsDialogState extends State<NotificationDetailsDialog> {
  bool _isAppealInProgress = false;
  Map<String, dynamic>? _bookingDetails;
  bool _isLoadingBooking = false;
  late bool _isRead; // Local state to track read status

  @override
  void initState() {
    super.initState();
    _isRead = widget.notification['isRead'] ?? false; // Initialize local read status
    // Load booking details if this is a booking notification
    if (widget.notification['type'] == 'booking' && widget.notification['relatedDocumentId'] != null) {
      _loadBookingDetails();
    }
  }

  // Get customer name
  Future<String?> _getCustomerName(String customerUsername) async {
    try {
      final db = DatabaseService();
      final userDoc = await db.getUserByUsername(customerUsername);
      if (userDoc != null && userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['name'] as String?;
      }
    } catch (e) {
      print('Error getting customer name: $e');
    }
    return null;
  }

  Future<void> _loadBookingDetails() async {
    setState(() => _isLoadingBooking = true);
    try {
      final db = DatabaseService();
      final bookingId = widget.notification['relatedDocumentId'];
      final booking = await db.getBookingById(bookingId);
      setState(() {
        _bookingDetails = booking;
        _isLoadingBooking = false;
      });
    } catch (e) {
      print('Error loading booking details: $e');
      setState(() => _isLoadingBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.notification['type'] as String;
    final createdAt = DatabaseService.parseDateTime(widget.notification['createdAt']);

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
      case 'booking':
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green;
        icon = Icons.calendar_today;
        break;
      default:
        backgroundColor = Colors.blue.withOpacity(0.1);
        borderColor = Colors.blue;
        icon = Icons.info;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Delete Button at the top right (only if read or _showDelete is true)
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: borderColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.notification['title'] ?? 'Notification',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button at the top right corner (always show now)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete Notification',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Notification'),
                          content: const Text('Are you sure you want to delete this notification?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        widget.onDelete(widget.notification['id']);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
            
            // Content - Made scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.notification['message'] ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Received: ${_formatDate(createdAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    
                    // Booking Details Section
                    if (type == 'booking') ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Booking Details',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingBooking)
                        const Center(child: CircularProgressIndicator())
                      else if (_bookingDetails != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<String?>(
                                future: _getCustomerName(_bookingDetails!['customerUsername']),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return _buildBookingDetailRow('Customer', 'Loading...');
                                  }
                                  final customerName = snapshot.data;
                                  return _buildBookingDetailRow('Customer', customerName ?? _bookingDetails!['customerUsername'] ?? 'N/A');
                                },
                              ),
                              _buildBookingDetailRow('House Address', _bookingDetails!['houseAddress'] ?? 'N/A'),
                              _buildBookingDetailRow('Store Date', _formatDate(DatabaseService.parseDateTime(_bookingDetails!['checkIn']))),
                              _buildBookingDetailRow('Pickup Date', _formatDate(DatabaseService.parseDateTime(_bookingDetails!['checkOut']))),
                              if (_bookingDetails!['quantity'] != null)
                                _buildBookingDetailRow('Quantity', '${_bookingDetails!['quantity']} items'),
                              _buildBookingDetailRow('Total Price', 'RM${_bookingDetails!['totalPrice']?.toString() ?? '0'}'),
                              if (_bookingDetails!['specialRequests'] != null && _bookingDetails!['specialRequests'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Special Requests:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(_bookingDetails!['specialRequests'].toString(), style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const Text('Booking details could not be loaded.', style: TextStyle(color: Colors.red)),
                      ],
                    ],
                    
                    if (type == 'ban') ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Appeal Information',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<bool>(
                              future: _checkExistingAppeal(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Text('Checking appeal status...');
                                }
                                
                                final hasAppeal = snapshot.data ?? false;
                                
                                if (hasAppeal) {
                                  return const Text(
                                    'You have already submitted an appeal for this ban. Please wait for admin review.',
                                    style: TextStyle(color: Colors.blue),
                                  );
                                } else {
                                  return const Text(
                                    'You can submit an appeal if you believe this ban was issued in error.',
                                    style: TextStyle(color: Colors.orange),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Booking Notification Action (for owners only)
                  if (type == 'booking' && _bookingDetails != null && 
                      _bookingDetails!['status'] == 'pending' && widget.userRole == 'owner') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Mark as read and close dialog
                          widget.onMarkAsRead(widget.notification['id']);
                          Navigator.of(context).pop(); // Close dialog
                          
                          // Navigate back to owner dashboard and switch to applications tab (index 1)
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const OwnerHomePage(initialTabIndex: 1),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.assignment),
                        label: const Text('Go to Applications'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Payment completion prompt (for customers with approved applications - non-cash only)
                  if (type == 'booking' && _bookingDetails != null && 
                      _bookingDetails!['status'] == 'approved' && 
                      _bookingDetails!['paymentMethod'] != 'cash' &&
                      _bookingDetails!['paymentStatus'] != 'completed' &&
                      widget.userRole == 'customer') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Mark as read and close dialog
                          widget.onMarkAsRead(widget.notification['id']);
                          Navigator.of(context).pop(); // Close dialog
                          
                          // Navigate back to customer dashboard (bookings tab is index 0)
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const CustHomePage(initialTabIndex: 0),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('Complete Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Regular Actions Row
                  Row(
                    children: [
                      if (!_isRead)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await widget.onMarkAsRead(widget.notification['id']);
                              setState(() {
                                _isRead = true; // Update local state immediately
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[600],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Mark as Read'),
                          ),
                        ),
                      if (!_isRead && type == 'ban') const SizedBox(width: 12),
                      if (type == 'ban')
                        Expanded(
                          child: FutureBuilder<bool>(
                            future: _checkExistingAppeal(),
                            builder: (context, snapshot) {
                              final hasAppeal = snapshot.data ?? false;
                              return ElevatedButton(
                                onPressed: hasAppeal || _isAppealInProgress ? null : () {
                                  setState(() => _isAppealInProgress = true);
                                  widget.onAppeal(widget.notification);
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasAppeal ? Colors.grey : Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(hasAppeal ? 'Appeal Submitted' : 'Submit Appeal'),
                              );
                            },
                          ),
                        ),
                      if (_isRead || type != 'ban') ...[
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkExistingAppeal() async {
    try {
      final db = DatabaseService();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      // Get username from email
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      
      if (usersSnapshot.docs.isEmpty) return false;
      
      final username = usersSnapshot.docs.first.id;
      
      // Check for pending appeals
      final existingAppeals = await db.getAllAppeals(status: 'pending');
      return existingAppeals.any((appeal) => appeal['username'] == username);
    } catch (e) {
      return false;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildBookingDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
