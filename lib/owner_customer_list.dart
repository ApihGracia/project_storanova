import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shared_widgets.dart';
import 'database.dart';

class OwnerCustomerListPage extends StatefulWidget {
  const OwnerCustomerListPage({Key? key}) : super(key: key);

  @override
  State<OwnerCustomerListPage> createState() => _OwnerCustomerListPageState();
}

class _OwnerCustomerListPageState extends State<OwnerCustomerListPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _pendingApplications = [];
  List<Map<String, dynamic>> _customerList = [];
  String? _ownerUsername;
  bool _isLoading = true;

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
          // Approved applications - keep in application list until payment is completed
          // Exception: cash payments go directly to customer list
          if (paymentMethod == 'cash') {
            customerList.add(booking);
          } else {
            // Online banking/e-wallet - stay in application list until paid
            pendingApplications.add(booking);
          }
        } else if (status == 'paid' || status == 'completed') {
          // Paid bookings go to customer list
          customerList.add(booking);
        }
        // Skip cancelled and rejected bookings
      }
      
      print('Owner customer list: ${pendingApplications.length} pending applications, ${customerList.length} customers');
      
      setState(() {
        _pendingApplications = pendingApplications;
        _customerList = customerList;
      });
    } catch (e) {
      print('Error loading customers: $e');
    }
  }

  // Get customer profile image URL
  Future<String?> _getCustomerProfileImage(String customerUsername) async {
    try {
      final userDoc = await _db.getUserByUsername(customerUsername);
      if (userDoc != null && userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['profileImageUrl'] as String?;
      }
    } catch (e) {
      print('Error getting customer profile image: $e');
    }
    return null;
  }

  // Get customer name
  Future<String?> _getCustomerName(String customerUsername) async {
    try {
      final userDoc = await _db.getUserByUsername(customerUsername);
      if (userDoc != null && userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['name'] as String?;
      }
    } catch (e) {
      print('Error getting customer name: $e');
    }
    return null;
  }

  // Get customer phone number
  Future<String?> _getCustomerPhone(String customerUsername) async {
    try {
      final userDoc = await _db.getUserByUsername(customerUsername);
      if (userDoc != null && userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['phone'] as String?;
      }
    } catch (e) {
      print('Error getting customer phone: $e');
    }
    return null;
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
        return 'PENDING APPLICATION';
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

  // Build storage status dropdown
  Widget _buildStorageStatusDropdown(Map<String, dynamic> booking) {
    final currentStatus = booking['storageStatus'] ?? 'not_stored';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStorageStatusColor(currentStatus),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _getStorageStatusTextColor(currentStatus)),
      ),
      child: DropdownButton<String>(
        value: currentStatus,
        underline: Container(),
        style: TextStyle(
          fontSize: 12,
          color: _getStorageStatusTextColor(currentStatus),
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: Colors.white,
        icon: Icon(
          Icons.arrow_drop_down,
          size: 16,
          color: _getStorageStatusTextColor(currentStatus),
        ),
        items: const [
          DropdownMenuItem(
            value: 'not_stored',
            child: Text('Not Stored', style: TextStyle(fontSize: 12)),
          ),
          DropdownMenuItem(
            value: 'stored',
            child: Text('Stored', style: TextStyle(fontSize: 12)),
          ),
          DropdownMenuItem(
            value: 'picked_up',
            child: Text('Picked Up', style: TextStyle(fontSize: 12)),
          ),
        ],
        onChanged: (String? newStatus) {
          if (newStatus != null && newStatus != currentStatus) {
            _updateStorageStatus(booking['id'], newStatus);
          }
        },
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

  // Get row color based on booking status and payment method
  Color _getRowColor(Map<String, dynamic> booking) {
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    
    if (paymentMethod == 'cash' && paymentStatus != 'completed') {
      return Colors.amber.shade50; // Highlight cash payments for owner attention
    }
    return Colors.white;
  }

  // Show booking details dialog
  void _showBookingDetails(Map<String, dynamic> booking) {
    final bool isPendingApplication = booking['status']?.toString().toLowerCase() == 'pending';
    
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
                          isPendingApplication ? 'Application Details' : 'Booking Details',
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
                  _buildDetailRow('Customer', booking['customerUsername'] ?? 'N/A'),
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
                            color: _getBookingStatusColor(booking['status'], booking['paymentMethod']),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getBookingStatusTextColor(booking['status'], booking['paymentMethod'])),
                          ),
                          child: Text(
                            _getBookingStatusText(booking['status'], booking['paymentMethod']),
                            style: TextStyle(
                              color: _getBookingStatusTextColor(booking['status'], booking['paymentMethod']),
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
                  if (booking['paymentStatus'] != null)
                    _buildDetailRow('Payment Status', booking['paymentStatus'].toString()),
                  
                  // Storage Status (only for approved bookings)
                  if (!isPendingApplication)
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
                  
                  // Action buttons for pending applications
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
                            label: const Text('Approve Application'),
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
                            label: const Text('Reject Application'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
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
        return 'Not Stored';
    }
  }

  // Build card for all bookings (both applications and customers)
  Widget _buildCustomerCard(Map<String, dynamic> booking) {
    final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    final isCashPayment = paymentMethod == 'cash';
    final isPaymentCompleted = paymentStatus == 'completed';
    final isPendingApplication = booking['status']?.toString().toLowerCase() == 'pending' || 
        (booking['status']?.toString().toLowerCase() == 'approved' && paymentMethod != 'cash');
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          color: _getRowColor(booking),
          borderRadius: BorderRadius.circular(12),
          border: isCashPayment && !isPaymentCompleted 
              ? Border.all(color: Colors.amber.shade300, width: 2)
              : isPendingApplication
                  ? Border.all(color: Colors.orange.shade300, width: 2)
                  : null,
        ),
        child: InkWell(
          onTap: () => _showBookingDetails(booking),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    // Customer profile image
                    FutureBuilder<String?>(
                      future: _getCustomerProfileImage(booking['customerUsername']),
                      builder: (context, snapshot) {
                        final imageUrl = snapshot.data;
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      Icons.person,
                                      color: Colors.grey.shade600,
                                      size: 24,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  color: Colors.grey.shade600,
                                  size: 24,
                                ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    // Customer info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<String?>(
                            future: _getCustomerName(booking['customerUsername']),
                            builder: (context, snapshot) {
                              final customerName = snapshot.data;
                              return Text(
                                '@${booking['customerUsername']}${customerName != null ? ' ($customerName)' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          const SizedBox(height: 1),
                          FutureBuilder<String?>(
                            future: _getCustomerPhone(booking['customerUsername']),
                            builder: (context, snapshot) {
                              final phone = snapshot.data;
                              return Text(
                                phone ?? 'No phone number',
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          const SizedBox(height: 2),
                          // Payment status indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getBookingStatusColor(booking['status'], booking['paymentMethod']),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getBookingStatusTextColor(booking['status'], booking['paymentMethod'])),
                            ),
                            child: Text(
                              isCashPayment 
                                  ? (isPaymentCompleted ? 'CASH - PAID' : 'CASH - PENDING')
                                  : _getBookingStatusText(booking['status'], booking['paymentMethod']),
                              style: TextStyle(
                                color: _getBookingStatusTextColor(booking['status'], booking['paymentMethod']),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Storage status dropdown (only for non-pending bookings)
                    if (!isPendingApplication)
                      _buildStorageStatusDropdown(booking),
                  ],
                ),
                
                // Action buttons for pending applications (only for truly pending, not pending payment)
                if (isPendingApplication && booking['status']?.toString().toLowerCase() == 'pending') ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveApplication(booking),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRejectDialog(booking),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (isPendingApplication && booking['status']?.toString().toLowerCase() == 'approved') ...[
                  // For approved applications waiting for payment, show a different message
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payment, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Waiting for customer payment',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const OwnerAppBar(title: 'Customer List'),
      endDrawer: const OwnerDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer List Section
                  Row(
                    children: [
                      const Icon(Icons.people, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'All Customers (${_customerList.length + _pendingApplications.length})',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_customerList.isEmpty && _pendingApplications.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No customers or applications',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        // Show pending applications first
                        ..._pendingApplications.map((booking) => Column(
                          children: [
                            _buildCustomerCard(booking),
                            const SizedBox(height: 8),
                          ],
                        )),
                        // Then show customer list
                        ..._customerList.map((booking) => Column(
                          children: [
                            _buildCustomerCard(booking),
                            const SizedBox(height: 8),
                          ],
                        )),
                      ],
                    ),
                ],
              ),
            ),
      bottomNavigationBar: OwnerNavBar(
        currentIndex: 1,
        onTap: (index) {},
      ),
    );
  }
}
