import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shared_widgets.dart';
import 'database.dart';

class OwnerCustomerListPage extends StatefulWidget {
  final bool isEmbedded; // Whether this is embedded in another Scaffold
  
  const OwnerCustomerListPage({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<OwnerCustomerListPage> createState() => _OwnerCustomerListPageState();
}

class _OwnerCustomerListPageState extends State<OwnerCustomerListPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _pendingApplications = [];
  List<Map<String, dynamic>> _customerList = [];
  String? _ownerUsername;
  bool _isLoading = true;
  int _currentApplicationPage = 0; // For pagination
  static const int _applicationsPerPage = 3;
  int _currentCustomerPage = 0; // For customer list pagination
  static const int _customersPerPage = 10;
  
  // Cache for customer data to avoid loading delays
  final Map<String, Map<String, dynamic>> _customerDataCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _ownerUsername = await _getOwnerUsername();
      print('Owner customer list: Owner username is $_ownerUsername');
      if (_ownerUsername != null) {
        await _loadCustomers();
      } else {
        print('Owner customer list: Could not get owner username');
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _getOwnerUsername() async {
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

  Future<void> _loadCustomers() async {
    if (_ownerUsername == null) return;
    
    try {
      final allBookings = await _db.getOwnerBookingRequests(_ownerUsername!);
      print('Owner customer list: Found ${allBookings.length} total bookings for owner $_ownerUsername');
      
      // Separate into applications and customer list
      final pendingApplications = <Map<String, dynamic>>[];
      final customerList = <Map<String, dynamic>>[];
      
      for (final booking in allBookings) {
        final status = booking['status']?.toString().toLowerCase();
        final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
        final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
        
        print('Booking status: $status, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus for customer ${booking['customerUsername']}');
        
        if (status == 'pending') {
          // Applications waiting for owner approval/rejection
          pendingApplications.add(booking);
        } else if (status == 'approved') {
          // For cash payments, move directly to customer list after approval
          if (paymentMethod == 'cash') {
            customerList.add(booking);
          } else {
            // For non-cash payments, check if they've paid
            if (paymentStatus == 'completed') {
              // Payment completed, move to customer list
              customerList.add(booking);
            } else {
              // Still waiting for payment
              pendingApplications.add(booking);
            }
          }
        } else if (status == 'paid' || status == 'completed') {
          // Completed bookings (after payment) go to customer list
          customerList.add(booking);
        }
        // Skip cancelled and rejected bookings
      }
      
      print('Owner customer list: ${pendingApplications.length} pending applications, ${customerList.length} customers');
      
      // Preload customer data to avoid display delays
      final allCustomerUsernames = {...pendingApplications, ...customerList}
          .map((booking) => booking['customerUsername'] as String?)
          .where((username) => username != null)
          .cast<String>()
          .toSet();
      
      for (final username in allCustomerUsernames) {
        await _getCustomerData(username); // This will cache the data
      }
      
      setState(() {
        _pendingApplications = pendingApplications;
        _customerList = customerList;
      });
    } catch (e) {
      print('Error loading customers: $e');
    }
  }

  // Get customer data (cached)
  Future<Map<String, dynamic>?> _getCustomerData(String customerUsername) async {
    if (_customerDataCache.containsKey(customerUsername)) {
      return _customerDataCache[customerUsername];
    }
    
    try {
      final userDoc = await _db.getUserByUsername(customerUsername);
      if (userDoc != null && userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _customerDataCache[customerUsername] = userData;
        return userData;
      }
    } catch (e) {
      print('Error getting customer data: $e');
    }
    return null;
  }

  // Get customer profile image URL
  Future<String?> _getCustomerProfileImage(String customerUsername) async {
    final userData = await _getCustomerData(customerUsername);
    return userData?['profileImageUrl'] as String?;
  }

  // Get customer name
  Future<String?> _getCustomerName(String customerUsername) async {
    final userData = await _getCustomerData(customerUsername);
    return userData?['name'] as String?;
  }

  // Get customer phone number
  Future<String?> _getCustomerPhone(String customerUsername) async {
    final userData = await _getCustomerData(customerUsername);
    return userData?['phone'] as String?;
  }

  // Booking status helper methods
  Color _getBookingStatusColor(String? status, String? paymentMethod) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade50;
      case 'approved':
        // If approved but payment method is not cash, show pending payment color
        if (paymentMethod?.toLowerCase() != 'cash') {
          return Colors.blue.shade50; // Pending payment color
        }
        return Colors.green.shade50;
      case 'paid':
      case 'completed':
        return Colors.blue.shade50;
      case 'cancelled':
        return Colors.grey.shade50;
      case 'rejected':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getBookingStatusTextColor(String? status, String? paymentMethod) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade700;
      case 'approved':
        // If approved but payment method is not cash, show pending payment color
        if (paymentMethod?.toLowerCase() != 'cash') {
          return Colors.blue.shade700; // Pending payment color
        }
        return Colors.green.shade700;
      case 'paid':
      case 'completed':
        return Colors.blue.shade700;
      case 'cancelled':
        return Colors.grey.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _getBookingStatusText(String? status, String? paymentMethod) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'approved':
        // If approved but payment method is not cash, show pending payment
        if (paymentMethod?.toLowerCase() != 'cash') {
          return 'PENDING PAYMENT';
        }
        return 'APPROVED';
      case 'paid':
        return 'PAID';
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'CANCELLED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status?.toUpperCase() ?? 'UNKNOWN';
    }
  }

  // Enhanced status text that considers payment status
  String _getEnhancedBookingStatusText(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    
    switch (status) {
      case 'pending':
        return 'PENDING APPLICATION';
      case 'approved':
        if (paymentMethod == 'cash') {
          // For cash payments, approved means ready for collection
          return 'APPROVED - CASH';
        } else {
          // For online payments, check if payment is completed
          if (paymentStatus == 'completed') {
            return 'PAID';
          } else {
            return 'PENDING PAYMENT';
          }
        }
      case 'paid':
        return 'PAID';
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'CANCELLED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status?.toUpperCase() ?? 'UNKNOWN';
    }
  }

  // Enhanced status color that considers payment status
  Color _getEnhancedBookingStatusColor(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    
    switch (status) {
      case 'pending':
        return Colors.orange.shade50;
      case 'approved':
        if (paymentMethod == 'cash') {
          return Colors.green.shade50;
        } else {
          if (paymentStatus == 'completed') {
            return Colors.blue.shade50; // Paid color
          } else {
            return Colors.orange.shade50; // Still pending payment
          }
        }
      case 'paid':
      case 'completed':
        return Colors.blue.shade50;
      case 'cancelled':
        return Colors.grey.shade50;
      case 'rejected':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  // Enhanced status text color that considers payment status
  Color _getEnhancedBookingStatusTextColor(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    
    switch (status) {
      case 'pending':
        return Colors.orange.shade700;
      case 'approved':
        if (paymentMethod == 'cash') {
          return Colors.green.shade700;
        } else {
          if (paymentStatus == 'completed') {
            return Colors.blue.shade700; // Paid color
          } else {
            return Colors.orange.shade700; // Still pending payment
          }
        }
      case 'paid':
      case 'completed':
        return Colors.blue.shade700;
      case 'cancelled':
        return Colors.grey.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  // Build storage status dropdown
  Widget _buildStorageStatusDropdown(Map<String, dynamic> booking, {bool isCompact = false}) {
    final currentStatus = booking['storageStatus'] ?? 'not_stored';
    final fontSize = isCompact ? 12.0 : 14.0; // Increased from 10.0 and 12.0
    final iconSize = isCompact ? 16.0 : 18.0; // Increased from 14.0 and 16.0
    final padding = isCompact 
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) // Increased padding slightly
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    
    // Check if this is a cash payment that hasn't been received yet
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    final cashReceived = booking['cashReceived'] ?? false;
    final isDisabled = paymentMethod == 'cash' && !cashReceived;
    
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade100 : _getStorageStatusColor(currentStatus),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDisabled ? Colors.grey.shade300 : _getStorageStatusTextColor(currentStatus)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              isCompact ? (currentStatus == 'picked_up' ? 'Picked' : (currentStatus == 'stored' ? 'Stored' : 'None')) : _getStorageDisplayText(currentStatus),
              style: TextStyle(
                fontSize: fontSize,
                color: isDisabled ? Colors.grey.shade500 : _getStorageStatusTextColor(currentStatus),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2), // Small spacing between text and icon
          DropdownButton<String>(
            value: currentStatus,
            underline: Container(),
            icon: Icon(
              Icons.arrow_drop_down,
              size: iconSize,
              color: isDisabled ? Colors.grey.shade400 : _getStorageStatusTextColor(currentStatus),
            ),
            isDense: true,
            items: isDisabled ? null : (isCompact ? [
              DropdownMenuItem(
                value: 'not_stored',
                child: Text('None', style: TextStyle(fontSize: fontSize)),
              ),
              DropdownMenuItem(
                value: 'stored',
                child: Text('Stored', style: TextStyle(fontSize: fontSize)),
              ),
              DropdownMenuItem(
                value: 'picked_up',
                child: Text('Picked', style: TextStyle(fontSize: fontSize)), // Shortened text for compact
              ),
            ] : [
              DropdownMenuItem(
                value: 'not_stored',
                child: Text('None', style: TextStyle(fontSize: fontSize)),
              ),
              DropdownMenuItem(
                value: 'stored',
                child: Text('Stored', style: TextStyle(fontSize: fontSize)),
              ),
              DropdownMenuItem(
                value: 'picked_up',
                child: Text('Picked Up', style: TextStyle(fontSize: fontSize)),
              ),
            ]),
            onChanged: isDisabled ? null : (String? newStatus) {
              if (newStatus != null && newStatus != currentStatus) {
                _updateStorageStatus(booking['id'], newStatus);
              }
            },
          ),
        ],
      ),
    );
  }

  // Get color for storage status
  Color _getStorageStatusColor(String status) {
    switch (status) {
      case 'stored':
        return Colors.blue.shade50;
      case 'picked_up':
        return Colors.green.shade50;
      case 'not_stored':
      default:
        return Colors.orange.shade50;
    }
  }

  // Get text color for storage status
  Color _getStorageStatusTextColor(String status) {
    switch (status) {
      case 'stored':
        return Colors.blue.shade700;
      case 'picked_up':
        return Colors.green.shade700;
      case 'not_stored':
      default:
        return Colors.orange.shade700;
    }
  }

  // Update storage status
  Future<void> _updateStorageStatus(String bookingId, String newStatus) async {
    try {
      await _db.updateStorageStatus(
        bookingId: bookingId,
        storageStatus: newStatus,
        updatedBy: _ownerUsername ?? 'owner',
      );
      
      await _loadCustomers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage status updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating storage status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating storage status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Approve booking application
  Future<void> _approveApplication(Map<String, dynamic> booking) async {
    try {
      await _db.updateBookingStatus(
        bookingId: booking['id'],
        status: 'approved',
        reviewedBy: _ownerUsername ?? 'owner',
        reviewComments: 'Application approved by owner',
      );
      
      await _loadCustomers(); // Refresh the lists
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error approving application: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving application'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Reject booking application
  Future<void> _rejectApplication(Map<String, dynamic> booking, String reason) async {
    try {
      await _db.updateBookingStatus(
        bookingId: booking['id'],
        status: 'rejected',
        reviewedBy: _ownerUsername ?? 'owner',
        reviewComments: reason.isNotEmpty ? reason : 'Application rejected by owner',
      );
      
      await _loadCustomers(); // Refresh the lists
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error rejecting application: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting application'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show reject dialog with reason input
  void _showRejectDialog(Map<String, dynamic> booking) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reject Application'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to reject the application from @${booking['customerUsername']}?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason for rejection (optional):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter reason for rejection...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _rejectApplication(booking, reasonController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  // Show booking details dialog
  void _showBookingDetails(Map<String, dynamic> booking) {
    final bool isPendingApplication = booking['status']?.toString().toLowerCase() == 'pending';
    final status = booking['status']?.toString().toLowerCase();
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    
    // Determine if this is an approved application that still needs payment handling
    final bool isApprovedApplication = status == 'approved' || 
        (status == 'approved' && paymentMethod != 'cash' && paymentStatus != 'completed');
    
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
                          (isPendingApplication || isApprovedApplication) ? 'Application Details' : 'Booking Details',
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
                  
                  // Customer Information
                  FutureBuilder<String?>(
                    future: _getCustomerName(booking['customerUsername']),
                    builder: (context, snapshot) {
                      // Since we preload customer data, this should resolve quickly
                      final customerName = snapshot.data;
                      if (customerName != null && customerName.isNotEmpty) {
                        return _buildDetailRow('Customer', customerName);
                      } else if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildDetailRow('Customer', 'Loading...');
                      } else {
                        return _buildDetailRow('Customer', '@${booking['customerUsername'] ?? 'N/A'}');
                      }
                    },
                  ),
                  // Customer Phone Number
                  FutureBuilder<String?>(
                    future: _getCustomerPhone(booking['customerUsername']),
                    builder: (context, snapshot) {
                      final customerPhone = snapshot.data;
                      if (customerPhone != null && customerPhone.isNotEmpty) {
                        return _buildDetailRow('Phone', customerPhone);
                      } else if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildDetailRow('Phone', 'Loading...');
                      } else {
                        return _buildDetailRow('Phone', 'Not set');
                      }
                    },
                  ),
                  _buildDetailRow('House Address', booking['houseAddress'] ?? 'No Address'),
                  
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
                            color: _getEnhancedBookingStatusColor(booking),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getEnhancedBookingStatusTextColor(booking)),
                          ),
                          child: Text(
                            _getEnhancedBookingStatusText(booking),
                            style: TextStyle(
                              color: _getEnhancedBookingStatusTextColor(booking),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
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
                  
                  // Storage Status (only for completed bookings in customer list)
                  if (!isPendingApplication && !isApprovedApplication)
                    _buildDetailRow('Storage Status', _getStorageDisplayText(booking['storageStatus'] ?? 'not_stored')),
                  
                  // Special Requests
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
                  
                  // Action buttons for pending applications only
                  if (isPendingApplication) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx); // Close dialog first
                              _approveApplication(booking);
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx); // Close dialog first
                              _showRejectDialog(booking);
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reject'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isApprovedApplication) ...[
                    // For approved applications - show different messages based on payment method and status
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildApprovedApplicationWidget(booking),
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
            width: 130,
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

  String _getStorageDisplayText(String status) {
    switch (status) {
      case 'stored':
        return 'Stored';
      case 'picked_up':
        return 'Picked Up';
      case 'not_stored':
      default:
        return 'None';
    }
  }

  // Build card for customer list (completed bookings only)
  Widget _buildCustomerCard(Map<String, dynamic> booking) {
    // Get the customer list number with pagination
    final customerIndex = _getCurrentPageCustomers().indexOf(booking) + 1 + (_currentCustomerPage * _customersPerPage);
    
    return InkWell(
      onTap: () => _showBookingDetails(booking),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 55, // Slightly increased height for better spacing
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0), // Reduced horizontal padding
        child: Row(
          children: [
            // List number (22px - reduced)
            SizedBox(
              width: 22,
              child: Text(
                '#$customerIndex',
                style: const TextStyle(
                  fontSize: 14, // Increased from 12
                  color: Colors.black, // Changed from grey to black
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6), // Reduced spacing
            
            // Customer profile image (36px - further reduced)
            SizedBox(
              width: 36,
              child: FutureBuilder<String?>(
                future: _getCustomerProfileImage(booking['customerUsername']),
                builder: (context, snapshot) {
                  final imageUrl = snapshot.data;
                  return Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.person,
                                color: Colors.grey.shade600,
                                size: 18, // Increased from 16
                              ),
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: Colors.grey.shade600,
                            size: 18, // Increased from 16
                          ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8), // Consistent spacing
            
            // Customer info and phone (flexible)
            Expanded(
              child: FutureBuilder<List<String?>>(
                future: Future.wait([
                  _getCustomerPhone(booking['customerUsername']),
                ]),
                builder: (context, snapshot) {
                  final phone = snapshot.data?[0];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '@${booking['customerUsername']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), // Increased from 13
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (phone != null && phone.isNotEmpty)
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 14, // Increased from 12
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  );
                },
              ),
            ),
            
            const SizedBox(width: 6), // Reduced spacing before status dropdown
            
            // Storage status dropdown (compact) - smaller size but bigger text
            SizedBox(
              width: 70, // Increased from 65 to prevent overflow
              child: _buildStorageStatusDropdown(booking, isCompact: true),
            ),
          ],
        ),
      ),
    );
  }

  // Build compact card for application list (5-column format)
  Widget _buildApplicationCard(Map<String, dynamic> booking, int index) {
    return InkWell(
      onTap: () => _showBookingDetails(booking),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 60, // Slightly increased height to accommodate phone number
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0), // Reduced horizontal padding
        child: Row(
          children: [
            // Column 1: Application Number (22px - reduced)
            SizedBox(
              width: 22,
              child: Center(
                child: Text(
                  '#${index + 1 + (_currentApplicationPage * _applicationsPerPage)}',
                  style: const TextStyle(
                    fontSize: 14, // Increased from 12
                    color: Colors.black, // Changed from grey to black
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4), // Reduced spacing
            
            // Column 2: Profile Image (36px - further optimized)
            SizedBox(
              width: 36,
              child: FutureBuilder<String?>(
                future: _getCustomerProfileImage(booking['customerUsername']),
                builder: (context, snapshot) {
                  final imageUrl = snapshot.data;
                  return Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.person,
                                color: Colors.grey.shade600,
                                size: 18, // Increased from 16
                              ),
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: Colors.grey.shade600,
                            size: 18, // Increased from 16
                          ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6), // Reduced spacing
            
            // Column 3: Username and Phone (flexible)
            Expanded(
              flex: 3,
              child: FutureBuilder<String?>(
                future: _getCustomerPhone(booking['customerUsername']),
                builder: (context, snapshot) {
                  final phone = snapshot.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '@${booking['customerUsername']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), // Increased from 13
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (phone != null && phone.isNotEmpty)
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 14, // Increased from 12
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  );
                },
              ),
            ),
            
            // Column 4: Item quantity (55px) - Increased to fit "X items" in one line
            SizedBox(
              width: 55,
              child: Text(
                '${booking['quantity'] ?? 0} items',
                style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600), // Increased from 13
                textAlign: TextAlign.center,
                maxLines: 1, // Changed to 1 line for better display
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            const SizedBox(width: 15), // Increased spacing between quantity and status
            
            // Column 5: Status (70px, right aligned) - Increased to accommodate larger text
            SizedBox(
              width: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2), // Minimal padding
                decoration: BoxDecoration(
                  color: _getBookingStatusColor(booking['status'], booking['paymentMethod']),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _getBookingStatusTextColor(booking['status'], booking['paymentMethod'])),
                ),
                child: Text(
                  _getBookingStatusText(booking['status'], booking['paymentMethod']),
                  style: TextStyle(
                    color: _getBookingStatusTextColor(booking['status'], booking['paymentMethod']),
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Increased from 10
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pagination helper methods for applications
  int _getTotalPages() {
    return (_pendingApplications.length / _applicationsPerPage).ceil();
  }

  List<Map<String, dynamic>> _getCurrentPageApplications() {
    final startIndex = _currentApplicationPage * _applicationsPerPage;
    final endIndex = (startIndex + _applicationsPerPage).clamp(0, _pendingApplications.length);
    return _pendingApplications.sublist(startIndex, endIndex);
  }

  // Pagination helper methods for customers
  int _getTotalCustomerPages() {
    return (_customerList.length / _customersPerPage).ceil();
  }

  List<Map<String, dynamic>> _getCurrentPageCustomers() {
    final startIndex = _currentCustomerPage * _customersPerPage;
    final endIndex = (startIndex + _customersPerPage).clamp(0, _customerList.length);
    return _customerList.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Application List Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pending_actions, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Application List (${_pendingApplications.length})',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        if (_pendingApplications.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'No pending applications',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        else
                          // Show applications with pagination
                          Column(
                            children: [
                              // Application list
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _getCurrentPageApplications().length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  color: Colors.grey.shade300,
                                ),
                                itemBuilder: (context, index) {
                                  final booking = _getCurrentPageApplications()[index];
                                  return _buildApplicationCard(booking, index);
                                },
                              ),
                              
                              // Pagination controls
                              if (_getTotalPages() > 1) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Previous button
                                    IconButton(
                                      onPressed: _currentApplicationPage > 0 
                                          ? () => setState(() => _currentApplicationPage--) 
                                          : null,
                                      icon: const Icon(Icons.arrow_back_ios),
                                      style: IconButton.styleFrom(
                                        backgroundColor: _currentApplicationPage > 0 
                                            ? Colors.blue.shade50 
                                            : Colors.grey.shade100,
                                        foregroundColor: _currentApplicationPage > 0 
                                            ? Colors.blue.shade700 
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    
                                    // Page indicator
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Text(
                                        'Page ${_currentApplicationPage + 1} of ${_getTotalPages()}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    
                                    // Next button
                                    IconButton(
                                      onPressed: _currentApplicationPage < _getTotalPages() - 1 
                                          ? () => setState(() => _currentApplicationPage++) 
                                          : null,
                                      icon: const Icon(Icons.arrow_forward_ios),
                                      style: IconButton.styleFrom(
                                        backgroundColor: _currentApplicationPage < _getTotalPages() - 1 
                                            ? Colors.blue.shade50 
                                            : Colors.grey.shade100,
                                        foregroundColor: _currentApplicationPage < _getTotalPages() - 1 
                                            ? Colors.blue.shade700 
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Customer List Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Customer List (${_customerList.length})',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        if (_customerList.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'You have no customers yet',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        else
                          // Show customers with pagination
                          Column(
                            children: [
                              // Customer list
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _getCurrentPageCustomers().length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  color: Colors.grey.shade300,
                                ),
                                itemBuilder: (context, index) {
                                  final booking = _getCurrentPageCustomers()[index];
                                  return _buildCustomerCard(booking);
                                },
                              ),
                              
                              // Customer pagination controls
                              if (_getTotalCustomerPages() > 1) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Previous button
                                    IconButton(
                                      onPressed: _currentCustomerPage > 0 
                                          ? () => setState(() => _currentCustomerPage--) 
                                          : null,
                                      icon: const Icon(Icons.arrow_back_ios),
                                      style: IconButton.styleFrom(
                                        backgroundColor: _currentCustomerPage > 0 
                                            ? Colors.blue.shade50 
                                            : Colors.grey.shade100,
                                        foregroundColor: _currentCustomerPage > 0 
                                            ? Colors.blue.shade700 
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    
                                    // Page indicator
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Text(
                                        'Page ${_currentCustomerPage + 1} of ${_getTotalCustomerPages()}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    
                                    // Next button
                                    IconButton(
                                      onPressed: _currentCustomerPage < _getTotalCustomerPages() - 1 
                                          ? () => setState(() => _currentCustomerPage++) 
                                          : null,
                                      icon: const Icon(Icons.arrow_forward_ios),
                                      style: IconButton.styleFrom(
                                        backgroundColor: _currentCustomerPage < _getTotalCustomerPages() - 1 
                                            ? Colors.blue.shade50 
                                            : Colors.grey.shade100,
                                        foregroundColor: _currentCustomerPage < _getTotalCustomerPages() - 1 
                                            ? Colors.blue.shade700 
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
    
    // If embedded, just return the content without Scaffold
    if (widget.isEmbedded) {
      return content;
    }
    
    // Otherwise, return full page with navigation
    return Scaffold(
      appBar: const OwnerAppBar(title: 'Customer Management'),
      endDrawer: const OwnerDrawer(),
      body: content,
      bottomNavigationBar: OwnerNavBar(
        currentIndex: 1, // Customer Management index
        onTap: (index) {
          // Navigation handled by shared widget
        },
      ),
    );
  }

  // Build widget for approved applications based on payment method and status
  Widget _buildApprovedApplicationWidget(Map<String, dynamic> booking) {
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    final cashReceived = booking['cashReceived'] ?? false; // Track if cash has been received
    
    if (paymentMethod == 'cash') {
      // For cash payments, show status and allow owner to update cash receipt
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cashReceived ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cashReceived ? Colors.green.shade300 : Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  cashReceived ? Icons.check_circle : Icons.payments,
                  color: cashReceived ? Colors.green.shade700 : Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cashReceived 
                        ? 'Cash payment received from customer'
                        : 'Application approved - Cash payment pending',
                    style: TextStyle(
                      color: cashReceived ? Colors.green.shade700 : Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _updateCashReceiptStatus(booking['id'], !cashReceived);
                      Navigator.pop(context); // Close dialog after update
                    },
                    icon: Icon(
                      cashReceived ? Icons.undo : Icons.check,
                      size: 18,
                    ),
                    label: Text(cashReceived ? 'Mark as Not Received' : 'Mark as Received'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cashReceived ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // For ewallet/online banking, check if payment is completed
      if (paymentStatus == 'completed') {
        // Payment already completed - no need to show waiting message
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment completed successfully via ${paymentMethod?.toUpperCase()}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // Still waiting for online payment
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.payment, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Application approved. Waiting for ${paymentMethod?.toUpperCase()} payment.',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  // Update cash receipt status using Firestore directly
  Future<void> _updateCashReceiptStatus(String bookingId, bool cashReceived) async {
    try {
      await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).update({
        'cashReceived': cashReceived,
        'cashReceivedAt': cashReceived ? DateTime.now().toIso8601String() : null,
        'cashReceivedBy': cashReceived ? (_ownerUsername ?? 'owner') : null,
      });
      
      await _loadCustomers(); // Refresh the lists
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cashReceived 
              ? 'Cash receipt status updated to received' 
              : 'Cash receipt status updated to not received'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating cash receipt status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating cash receipt status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}