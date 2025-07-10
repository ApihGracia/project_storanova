import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';
import 'notifications_page.dart';
import 'shared_widgets.dart';
import 'house_details_dialog.dart';
import 'cust_wishlist.dart';
import 'cust_profile.dart' as cust;


class CustHomePage extends StatefulWidget {
  const CustHomePage({Key? key}) : super(key: key);

  @override
  _CustHomePageState createState() => _CustHomePageState();
}

class _CustHomePageState extends State<CustHomePage> {
  int _currentIndex = 0;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('AppUsers')
        .where('email', isEqualTo: user.email)
        .limit(1)
        .get();
    
    if (usersSnapshot.docs.isNotEmpty && mounted) {
      setState(() {
        _username = usersSnapshot.docs.first.id;
      });
    }
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'StoraNova';
      case 1:
        return 'Wishlist';
      case 2:
        return 'Notifications';
      case 3:
        return _username != null ? '@$_username' : 'Profile';
      default:
        return 'StoraNova';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomerAppBar(title: _getPageTitle(_currentIndex)),
      endDrawer: const CustomerDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CustDashboardContent(),
          CustWishlistPage(isEmbedded: true),
          NotificationsPage(expectedRole: 'customer', isEmbedded: true),
          cust.ProfileScreen(isEmbedded: true),
        ],
      ),
      bottomNavigationBar: CustomerNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class CustDashboardContent extends StatefulWidget {
  @override
  _CustDashboardContentState createState() => _CustDashboardContentState();
}

class _CustDashboardContentState extends State<CustDashboardContent> {
  String _sortBy = 'perDay'; // 'perDay' or 'perWeek'
  late Future<List<Map<String, dynamic>>> _housesFuture;
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _bookings = [];
  bool _isBookingsIndexBuilding = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _checkUserBanStatus();
    _housesFuture = _fetchHouses();
    _loadBookings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkUserBanStatus() async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username != null) {
        final userDoc = await _db.getUserByUsername(username);
        if (userDoc != null && userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final isUserBanned = userData['isBanned'] == true;
          
          if (isUserBanned) {
            // Redirect to notifications page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationsPage(expectedRole: 'customer'),
              ),
            );
            return;
          }
        }
      }
    } catch (e) {
      print('Error checking ban status: $e');
    }
  }

  Future<String?> _getUsernameFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    // Try to get username from AppUsers by email lookup
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('AppUsers')
        .where('email', isEqualTo: user.email)
        .limit(1)
        .get();
    
    if (usersSnapshot.docs.isNotEmpty) {
      return usersSnapshot.docs.first.id; // Document ID is the username
    }
    
    return null;
  }

  void _refreshHouses() {
    setState(() {
      _housesFuture = _fetchHouses();
    });
  }

  void _showHouseDetails(Map<String, dynamic> house) {
    showDialog(
      context: context,
      builder: (context) => HouseDetailsDialog(house: house),
    );
  }

  Future<void> _editBooking(Map<String, dynamic> booking) async {
    // For now, show a simple dialog to inform user about editing
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Booking'),
        content: Text('Editing bookings will be available soon. You can currently delete the booking for ${booking['houseAddress'] ?? 'this address'} and create a new one.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: Text('Are you sure you want to delete your booking for ${booking['houseAddress'] ?? 'this address'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteBooking(booking['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking deleted successfully')),
        );
        _loadBookings(); // Refresh bookings
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting booking: $e')),
        );
      }
    }
  }

  Color _getBookingStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade50;
      case 'approved':
        return Colors.green.shade50;
      case 'rejected':
        return Colors.red.shade50;
      case 'cancelled':
        return Colors.grey.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getBookingStatusTextColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade700;
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'cancelled':
        return Colors.grey.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getBookingStatusColorForPayment(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    
    if (status == 'approved' && 
        paymentStatus != 'completed' && 
        paymentMethod != 'cash') {
      return Colors.orange.shade50; // Use orange for payment required
    }
    
    return _getBookingStatusColor(booking['status']);
  }

  Color _getBookingStatusTextColorForPayment(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    
    if (status == 'approved' && 
        paymentStatus != 'completed' && 
        paymentMethod != 'cash') {
      return Colors.orange.shade700; // Use orange for payment required
    }
    
    return _getBookingStatusTextColor(booking['status']);
  }

  IconData _getBookingStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.close;
      default:
        return Icons.help;
    }
  }

  IconData _getBookingStatusIconForPayment(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    
    if (status == 'approved' && 
        paymentStatus != 'completed' && 
        paymentMethod != 'cash') {
      return Icons.payment; // Use payment icon for payment required
    }
    
    return _getBookingStatusIcon(booking['status']);
  }

  String _getBookingStatusText(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    
    if (status == 'approved' && 
        paymentStatus != 'completed' && 
        paymentMethod != 'cash') {
      return 'PAYMENT REQUIRED';
    }
    
    return booking['status']?.toString().toUpperCase() ?? 'UNKNOWN';
  }

  Future<void> _loadBookings() async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username != null) {
        final allBookings = await _db.getUserBookings(username);
        // Filter to show only active bookings (not completed, cancelled, or paid)
        final activeBookings = allBookings.where((booking) {
          final status = booking['status']?.toString().toLowerCase();
          final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
          
          // Only show pending and approved bookings that haven't been paid yet
          return status == 'pending' || 
                 (status == 'approved' && paymentStatus != 'completed');
        }).toList();
        
        setState(() {
          _bookings = activeBookings;
          _isBookingsIndexBuilding = false;
        });
      }
    } catch (e) {
      print('Error loading bookings: $e');
      // If index is building, show empty list for now
      if (e.toString().contains('index is currently building')) {
        setState(() {
          _bookings = [];
          _isBookingsIndexBuilding = true;
        });
      } else {
        setState(() {
          _isBookingsIndexBuilding = false;
        });
      }
    }
  }

  // Helper function to format date in dd/mm/yyyy format
  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        return '';
      }
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return '';
    }
  }

  void _showBookingDetails(BuildContext context, Map<String, dynamic> booking) {
    // Helper function to format date
    String formatDate(dynamic date) {
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

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Booking Details',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  // House Information
                  _buildDetailRow('Address', booking['houseAddress'] ?? 'No Address'),
                  _buildDetailRow('Owner', booking['ownerUsername'] ?? 'N/A'),
                  
                  // Booking Status - aligned with other details
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            'Status',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Text(
                          ': ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getBookingStatusColor(booking['status']),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getBookingStatusTextColor(booking['status'])),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getBookingStatusIcon(booking['status']),
                                size: 16,
                                color: _getBookingStatusTextColor(booking['status']),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                booking['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                                style: TextStyle(
                                  color: _getBookingStatusTextColor(booking['status']),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Dates
                  _buildDetailRow('Store Date', formatDate(booking['checkIn'])),
                  _buildDetailRow('Pickup Date', formatDate(booking['checkOut'])),
                  
                  // Quantity and Service Details
                  if (booking['quantity'] != null)
                    _buildDetailRow('Quantity', '${booking['quantity']} items'),
                  if (booking['usePickupService'] == true)
                    _buildDetailRow('Pickup Service', 'Yes'),
                  
                  // Pricing Details
                  if (booking['priceBreakdown'] != null)
                    _buildDetailRow('Price Breakdown', booking['priceBreakdown'].toString()),
                  _buildDetailRow('Total Price', 'RM${booking['totalPrice']?.toString() ?? '0'}'),
                  
                  // Payment Details
                  if (booking['paymentMethod'] != null)
                    _buildDetailRow('Payment Method', booking['paymentMethod'].toString()),
                  
                  // Special Requests - aligned with other details
                  if (booking['specialRequests'] != null && booking['specialRequests'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 130,
                                child: Text(
                                  'Special Requests',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Text(
                                ': ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              booking['specialRequests'].toString(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Action Buttons (if pending)
                  if (booking['status']?.toLowerCase() == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _editBooking(booking);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Booking'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _deleteBooking(booking);
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  

                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130, // Slightly wider for better alignment
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Colors.green.shade700 : Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? Colors.green.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Show bookings at the top if any exist
            if (_bookings.isNotEmpty) ...[
              const Text(
                'Your Bookings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bookings.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final booking = _bookings[index];
                  final isPending = booking['status']?.toLowerCase() == 'pending';
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getBookingStatusColorForPayment(booking),
                      ),
                      child: InkWell(
                        onTap: () => _showBookingDetails(context, booking),
                        child: SizedBox(
                          height: 80, // Fixed height for consistent rows
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            child: Row(
                              children: [
                                // Status icon on the left
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _getBookingStatusTextColorForPayment(booking).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getBookingStatusIconForPayment(booking),
                                    size: 28,
                                    color: _getBookingStatusTextColorForPayment(booking),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Content section - takes remaining space
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        booking['houseAddress'] ?? 'No Address',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getBookingStatusText(booking),
                                        style: TextStyle(
                                          color: _getBookingStatusTextColorForPayment(booking),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (booking['checkIn'] != null)
                                        Text(
                                          'Store: ${_formatDate(booking['checkIn'])}',
                                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                // Action buttons based on booking status - aligned to the right
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ...(() {
                                      if (isPending) {
                                        return [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18),
                                            onPressed: () => _editBooking(booking),
                                            tooltip: 'Edit booking',
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () => _deleteBooking(booking),
                                            tooltip: 'Delete booking',
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                          ),
                                        ];
                                      } else if (booking['status']?.toLowerCase() == 'approved' && 
                                                booking['paymentStatus']?.toLowerCase() != 'completed' &&
                                                booking['paymentMethod']?.toLowerCase() != 'cash') {
                                        return [
                                          ElevatedButton.icon(
                                            onPressed: () => _showPaymentDialog(booking),
                                            icon: const Icon(Icons.payment, size: 16),
                                            label: const Text('Pay Now', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(80, 32),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                        ];
                                      } else {
                                        return <Widget>[];
                                      }
                                    })(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 32, thickness: 2),
            ],
            
            // Show loading indicator if bookings index is building
            if (_isBookingsIndexBuilding) ...[
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Setting up your bookings...',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Database indexes are building. Your bookings will appear here shortly.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Search bar
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by house address...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Houses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sort by: '),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.transparent,
                        ),
                        child: DropdownButton<String>(
                          value: _sortBy,
                          isDense: true,
                          isExpanded: false,
                          underline: Container(), // Remove underline
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Colors.black87),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          items: const [
                            DropdownMenuItem(value: 'perDay', child: Text('Price (Low to High)')),
                            DropdownMenuItem(value: 'perWeek', child: Text('Price (High to Low)')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _sortBy = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _housesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshHouses,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No houses available at the moment. Please check back later!', style: TextStyle(fontSize: 18)),
                    );
                  }
                  final houses = snapshot.data!;
                  List<Map<String, dynamic>> sortedHouses = List.from(houses);
                  
                  // Filter houses based on search query
                  if (_searchQuery.isNotEmpty) {
                    sortedHouses = sortedHouses.where((house) {
                      final address = (house['address'] ?? '').toLowerCase();
                      return address.contains(_searchQuery);
                    }).toList();
                  }
                  
                  // Sort by price - prioritize new pricing structure, fallback to old structure
                  if (_sortBy == 'perDay' || _sortBy == 'perWeek') {
                    sortedHouses.sort((a, b) {
                      // Try new pricing structure first
                      double aPrice = double.infinity;
                      double bPrice = double.infinity;
                      
                      if (a['pricePerItem'] != null && a['pricePerItem'].toString().isNotEmpty) {
                        aPrice = double.tryParse(a['pricePerItem'].toString()) ?? double.infinity;
                      } else if (a['prices'] is List && (a['prices'] as List).isNotEmpty) {
                        final aPrices = (a['prices'] as List).map((p) => p['amount'] is num ? p['amount'] : double.tryParse(p['amount'].toString()) ?? double.infinity).toList();
                        aPrice = aPrices.reduce((v, e) => v < e ? v : e);
                      }
                      
                      if (b['pricePerItem'] != null && b['pricePerItem'].toString().isNotEmpty) {
                        bPrice = double.tryParse(b['pricePerItem'].toString()) ?? double.infinity;
                      } else if (b['prices'] is List && (b['prices'] as List).isNotEmpty) {
                        final bPrices = (b['prices'] as List).map((p) => p['amount'] is num ? p['amount'] : double.tryParse(p['amount'].toString()) ?? double.infinity).toList();
                        bPrice = bPrices.reduce((v, e) => v < e ? v : e);
                      }
                      
                      // Low to high for 'perDay', high to low for 'perWeek'
                      return _sortBy == 'perDay' ? aPrice.compareTo(bPrice) : bPrice.compareTo(aPrice);
                    });
                  }
                  
                  // Show message if no houses match search
                  if (sortedHouses.isEmpty && _searchQuery.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('No houses found for "${_searchController.text}"', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Try searching with different keywords', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  // --- ListView and dialog logic ---
                  // _showFullScreenImage must be declared before use
                  return ListView.separated(
                    itemCount: sortedHouses.length,
                    separatorBuilder: (context, idx) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final house = sortedHouses[idx];
                      return Card(
                        elevation: 2,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showHouseDetails(house),
                          child: SizedBox(
                            height: 100, // Fixed height for consistent rows
                            child: Row(
                              children: [
                                // Image section - fills the left side completely
                                Container(
                                  width: 100, // Square dimensions
                                  height: 100,
                                  child: house['imageUrls'] != null && house['imageUrls'] is List && (house['imageUrls'] as List).isNotEmpty
                                      ? Image.network(
                                          (house['imageUrls'] as List).first,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.home, size: 40, color: Colors.blue),
                                          ),
                                        )
                                      : (house['imageUrl'] != null && house['imageUrl'].toString().isNotEmpty
                                          ? Image.network(
                                              house['imageUrl'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.home, size: 40, color: Colors.blue),
                                              ),
                                            )
                                          : Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.home, size: 40, color: Colors.blue),
                                            )),
                                ),
                                // Content section - takes remaining space
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          house['address'] ?? 'No Address',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        if (house['owner'] != null && house['owner'].toString().isNotEmpty)
                                          Text(
                                            'Owner: ${house['owner']}',
                                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 1),
                                        // Show new pricing structure if available, fallback to old structure
                                        if (house['pricePerItem'] != null && house['pricePerItem'].toString().isNotEmpty)
                                          Text(
                                            'RM${house['pricePerItem']} per item',
                                            style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                                          )
                                        else if (house['prices'] != null && house['prices'] is List && (house['prices'] as List).isNotEmpty)
                                          Text(
                                            'From RM${(house['prices'] as List).map((p) => p['amount'] is num ? p['amount'] : double.tryParse(p['amount'].toString()) ?? '').where((v) => v != '').fold<double?>(null, (min, v) => min == null || (v is num && v < min) ? v : min)}',
                                            style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                                          ),
                                        const SizedBox(height: 1),
                                        if (house['availableFrom'] != null && house['availableTo'] != null)
                                          Text(
                                            'Available: ${_formatDate(house['availableFrom'])} to ${_formatDate(house['availableTo'])}',
                                            style: const TextStyle(fontSize: 11, color: Colors.green),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
  }

  Future<List<Map<String, dynamic>>> _fetchHouses() async {
    try {
      // Fetch only approved and available houses
      final houseSnapshot = await FirebaseFirestore.instance.collection('ApprovedHouses')
          .where('isAvailable', isEqualTo: true)
          .get();
      if (houseSnapshot.docs.isEmpty) return [];

      List<Map<String, dynamic>> houses = [];
      for (var doc in houseSnapshot.docs) {
        final data = doc.data();
        
        // Filter out banned houses
        final isHouseBanned = data['isHouseBanned'] ?? false;
        if (isHouseBanned) continue;
        
        houses.add({
          'id': doc.id, // Add the document ID as houseId
          'address': data['address'] ?? '',
          'pricePerDay': data['pricePerDay'],
          'pricePerWeek': data['pricePerWeek'],
          'imageUrl': data['imageUrl'] ?? '',
          'imageUrls': data['imageUrls'] ?? [],
          'owner': data['owner'] ?? data['ownerName'] ?? '', // Use owner name from approved data
          'ownerUsername': data['ownerUsername'] ?? doc.id, // Add ownerUsername
          'phone': data['phone'] ?? '',
          'prices': data['prices'] ?? [],
          'availableFrom': data['availableFrom'],
          'availableTo': data['availableTo'],
          'description': data['description'] ?? '',
          // New fields from updated application form
          'paymentMethods': data['paymentMethods'] ?? {},
          'maxItemQuantity': data['maxItemQuantity'],
          'pricePerItem': data['pricePerItem'],
          'offerPickupService': data['offerPickupService'] ?? false,
          'pickupServiceCost': data['pickupServiceCost'],
        });
      }
      return houses;
    } catch (e) {
      // Re-throw the error so FutureBuilder can handle it
      throw Exception('Failed to fetch houses: $e');
    }
  }

  void _showPaymentDialog(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Complete Payment',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),
                
                // Booking Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['houseAddress'] ?? 'No Address',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      // Two-column layout for details
                      _buildPaymentDetailRow('Store Date', _formatDate(booking['checkIn'])),
                      _buildPaymentDetailRow('Pickup Date', _formatDate(booking['checkOut'])),
                      _buildPaymentDetailRow('Items', '${booking['quantity'] ?? 0}'),
                      if (booking['usePickupService'] == true) ...[
                        _buildPaymentDetailRow('Pickup Service', 'Yes'),
                        _buildPaymentDetailRow('Delivery Charge', 'RM${booking['pickupServiceCost']?.toString() ?? '0'}'),
                      ],
                      const Divider(height: 20),
                      _buildPaymentDetailRow(
                        'Total Amount',
                        'RM${booking['totalPrice']?.toString() ?? '0'}',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Payment Method
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.credit_card, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Method',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              booking['paymentMethod']?.toString().toUpperCase() ?? 'ONLINE',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _cancelBooking(booking);
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel Booking'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _completePayment(booking);
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('Pay Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _completePayment(Map<String, dynamic> booking) async {
    try {
      await _db.completePayment(bookingId: booking['id']);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment completed successfully! Your booking is confirmed.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh bookings
      _loadBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final username = await _getUsernameFromFirestore();
        await _db.cancelBooking(
          bookingId: booking['id'],
          cancelledBy: username ?? 'customer',
          cancelReason: 'Cancelled by customer during payment process',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully.'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // Refresh bookings
        _loadBookings();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}