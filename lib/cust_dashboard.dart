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
  final int initialTabIndex;
  
  const CustHomePage({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  _CustHomePageState createState() => _CustHomePageState();
}

class _CustHomePageState extends State<CustHomePage> {
  late int _currentIndex;
  String? _username;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex; // Use the provided initial tab index
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
  
  // Booking editing state
  bool _isEditingBooking = false;
  final _bookingFormKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _specialRequestsController = TextEditingController();
  DateTime? _editingCheckIn;
  DateTime? _editingCheckOut;
  String? _editingPaymentMethod;
  bool _editingUsePickupService = false;

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
    _quantityController.dispose();
    _specialRequestsController.dispose();
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
            // Navigate to notifications page with proper navigation
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => NotificationsPage(expectedRole: 'customer'),
              ),
              (route) => false,
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

  // In-place booking editing methods
  void _cancelEditingBooking() {
    setState(() {
      _isEditingBooking = false;
      
      // Clear controllers
      _quantityController.clear();
      _specialRequestsController.clear();
      _editingCheckIn = null;
      _editingCheckOut = null;
      _editingPaymentMethod = null;
      _editingUsePickupService = false;
    });
  }

  Future<void> _saveBookingChanges(Map<String, dynamic> booking) async {
    if (!_bookingFormKey.currentState!.validate()) {
      return;
    }

    try {
      // Create updated booking data
      final updatedBooking = <String, dynamic>{};
      
      // Update basic fields
      if (_quantityController.text.isNotEmpty) {
        updatedBooking['quantity'] = int.parse(_quantityController.text);
      }
      updatedBooking['specialRequests'] = _specialRequestsController.text;
      
      if (_editingCheckIn != null) {
        updatedBooking['checkIn'] = Timestamp.fromDate(_editingCheckIn!);
      }
      if (_editingCheckOut != null) {
        updatedBooking['checkOut'] = Timestamp.fromDate(_editingCheckOut!);
      }
      if (_editingPaymentMethod != null) {
        updatedBooking['paymentMethod'] = _editingPaymentMethod;
      }
      updatedBooking['usePickupService'] = _editingUsePickupService;
      updatedBooking['updatedAt'] = FieldValue.serverTimestamp();

      // Recalculate total price
      double newTotalPrice = _calculateUpdatedPrice(booking);
      updatedBooking['totalPrice'] = newTotalPrice;
      
      // Update price breakdown
      String priceBreakdown = _generatePriceBreakdown(booking, newTotalPrice);
      updatedBooking['priceBreakdown'] = priceBreakdown;

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('Bookings')
          .doc(booking['id'])
          .update(updatedBooking);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking updated successfully')),
      );

      // Refresh bookings and exit edit mode
      _loadBookings();
      _cancelEditingBooking();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating booking: $e')),
      );
    }
  }

  // Calculate updated price based on current editing values
  double _calculateUpdatedPrice(Map<String, dynamic> booking) {
    // Get current editing values or fallback to original booking values
    final quantity = _quantityController.text.isNotEmpty 
        ? int.parse(_quantityController.text) 
        : (booking['quantity'] ?? 1);
    
    // Get the actual pricing data from the booking (this was stored when booking was created)
    final pricePerItem = booking['pricePerItem'] != null 
        ? double.tryParse(booking['pricePerItem'].toString()) ?? 0.0
        : 0.0;
    
    final pickupServiceCost = booking['pickupServiceCost'] != null 
        ? double.tryParse(booking['pickupServiceCost'].toString()) ?? 0.0
        : 0.0;
    
    // Calculate base price: quantity × price per item (no days multiplication for item-based pricing)
    double basePrice = quantity * pricePerItem;
    
    // Add pickup service cost if selected
    double pickupCost = _editingUsePickupService ? pickupServiceCost : 0.0;
    
    return basePrice + pickupCost;
  }

  // Generate price breakdown text
  String _generatePriceBreakdown(Map<String, dynamic> booking, double totalPrice) {
    final quantity = _quantityController.text.isNotEmpty 
        ? int.parse(_quantityController.text) 
        : (booking['quantity'] ?? 1);
    
    // Get the actual pricing data from the booking
    final pricePerItem = booking['pricePerItem'] != null 
        ? double.tryParse(booking['pricePerItem'].toString()) ?? 0.0
        : 0.0;
    
    final pickupServiceCost = booking['pickupServiceCost'] != null 
        ? double.tryParse(booking['pickupServiceCost'].toString()) ?? 0.0
        : 0.0;
    
    double pickupCost = _editingUsePickupService ? pickupServiceCost : 0.0;
    double basePrice = totalPrice - pickupCost;
    
    String breakdown = '$quantity items × RM${pricePerItem.toStringAsFixed(2)} = RM${basePrice.toStringAsFixed(2)}';
    if (_editingUsePickupService) {
      breakdown += ', Pickup: RM${pickupCost.toStringAsFixed(2)}';
    }
    
    return breakdown;
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

    // Date picker helper
    Future<void> selectDate(bool isCheckIn) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: isCheckIn 
            ? (_editingCheckIn ?? DateTime.now())
            : (_editingCheckOut ?? DateTime.now().add(const Duration(days: 1))),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

      if (picked != null) {
        setState(() {
          if (isCheckIn) {
            _editingCheckIn = picked;
            if (_editingCheckOut != null && _editingCheckOut!.isBefore(picked.add(const Duration(days: 1)))) {
              _editingCheckOut = null;
            }
          } else {
            _editingCheckOut = picked;
          }
        });
      }
    }

    // Simple start editing - just use booking data
    void startEditing() {
      // Helper function to parse dates from various formats
      DateTime? parseDate(dynamic date) {
        if (date == null) return null;
        if (date is Timestamp) return date.toDate();
        if (date is String) {
          try {
            return DateTime.parse(date);
          } catch (e) {
            return null;
          }
        }
        return null;
      }
      
      setState(() {
        _isEditingBooking = true;
        
        // Initialize editing values with current booking data
        _quantityController.text = booking['quantity']?.toString() ?? '';
        _specialRequestsController.text = booking['specialRequests']?.toString() ?? '';
        
        _editingCheckIn = parseDate(booking['checkIn']) ?? DateTime.now();
        _editingCheckOut = parseDate(booking['checkOut']) ?? DateTime.now().add(const Duration(days: 1));
        
        _editingPaymentMethod = booking['paymentMethod']?.toString();
        _editingUsePickupService = booking['usePickupService'] == true;
      });
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _bookingFormKey,
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
                              onPressed: () {
                                if (_isEditingBooking) {
                                  _cancelEditingBooking();
                                }
                                Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 12),
                        
                        // House Information
                        _buildDetailRow('Address', booking['houseAddress'] ?? 'No Address'),
                        _buildDetailRow('Owner', booking['ownerUsername'] ?? 'N/A'),
                        
                        // Booking Status
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
                        
                        // Store Date - Editable in edit mode
                        if (_isEditingBooking) ...[
                          const Text('Store Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => selectDate(true),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today),
                                  const SizedBox(width: 8),
                                  Text(_editingCheckIn != null 
                                      ? formatDate(Timestamp.fromDate(_editingCheckIn!))
                                      : 'Select date'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else 
                          _buildDetailRow('Store Date', formatDate(booking['checkIn'])),
                        
                        // Pickup Date - Editable in edit mode
                        if (_isEditingBooking) ...[
                          const Text('Pickup Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => selectDate(false),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today),
                                  const SizedBox(width: 8),
                                  Text(_editingCheckOut != null 
                                      ? formatDate(Timestamp.fromDate(_editingCheckOut!))
                                      : 'Select date'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else 
                          _buildDetailRow('Pickup Date', formatDate(booking['checkOut'])),
                        
                        // Quantity - Editable in edit mode
                        if (booking['quantity'] != null) ...[
                          if (_isEditingBooking) ...[
                            const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                suffixText: 'items',
                              ),
                              onChanged: (value) {
                                // Trigger dialog state update when quantity changes
                                setDialogState(() {});
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter quantity';
                                final quantity = int.tryParse(value);
                                if (quantity == null || quantity <= 0) return 'Please enter a valid quantity';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ] else 
                            _buildDetailRow('Quantity', '${booking['quantity']} items'),
                        ],
                        
                        // Pickup Service - Editable in edit mode
                        if (_isEditingBooking) ...[
                          CheckboxListTile(
                            title: const Text('Use Pickup Service'),
                            subtitle: Text('Additional cost: RM${(booking['pickupServiceCost'] != null ? double.tryParse(booking['pickupServiceCost'].toString()) ?? 0.0 : 0.0).toStringAsFixed(0)}'),
                            value: _editingUsePickupService,
                            onChanged: (value) {
                              setDialogState(() {
                                _editingUsePickupService = value ?? false;
                              });
                            },
                            dense: true,
                          ),
                          const SizedBox(height: 12),
                        ] else if (booking['usePickupService'] == true)
                          _buildDetailRow('Pickup Service', 'Yes'),
                        
                        // Payment Method - Editable in edit mode
                        if (_isEditingBooking) ...[
                          const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            value: _editingPaymentMethod,
                            items: ['Cash', 'Online Banking', 'E-Wallet'].map<DropdownMenuItem<String>>((method) {
                              return DropdownMenuItem(value: method, child: Text(method));
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                _editingPaymentMethod = value;
                              });
                            },
                            validator: (value) => value == null ? 'Please select a payment method' : null,
                          ),
                          const SizedBox(height: 12),
                        ] else if (booking['paymentMethod'] != null)
                          _buildDetailRow('Payment Method', booking['paymentMethod'].toString()),
                        
                        // Pricing Details
                        if (booking['priceBreakdown'] != null)
                          _buildDetailRow('Price Breakdown', booking['priceBreakdown'].toString()),
                        
                        // Show updated total price in edit mode
                        if (_isEditingBooking) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Updated Price:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _generatePriceBreakdown(booking, _calculateUpdatedPrice(booking)),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total: RM${_calculateUpdatedPrice(booking).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else
                          _buildDetailRow('Total Price', 'RM${booking['totalPrice']?.toString() ?? '0'}'),
                        
                        // Special Requests - Editable in edit mode
                        if (_isEditingBooking) ...[
                          const Text('Special Requests:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _specialRequestsController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Any special requests or notes...',
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else if (booking['specialRequests'] != null && booking['specialRequests'].toString().isNotEmpty) ...[
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
                        ],
                        
                        // Action Buttons
                        if (booking['status']?.toLowerCase() == 'pending') ...[
                          if (!_isEditingBooking) ...[
                            // View mode buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      startEditing();
                                      setDialogState(() {});
                                    },
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit'),
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
                          ] else ...[
                            // Edit mode buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      _cancelEditingBooking();
                                      setDialogState(() {});
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _saveBookingChanges(booking);
                                      Navigator.pop(ctx);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Save Changes'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
          // Refresh button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _housesFuture = _fetchHouses();
                  });
                  _loadBookings();
                },
                tooltip: 'Refresh',
              ),
            ],
          ),
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
                                            onPressed: () => _showBookingDetails(context, booking),
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