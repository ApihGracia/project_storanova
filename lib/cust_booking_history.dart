import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';
import 'shared_widgets.dart';

class CustBookingHistory extends StatefulWidget {
  const CustBookingHistory({Key? key}) : super(key: key);

  @override
  _CustBookingHistoryState createState() => _CustBookingHistoryState();
}

class _CustBookingHistoryState extends State<CustBookingHistory> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _historyBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookingHistory();
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

  Future<void> _loadBookingHistory() async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username != null) {
        final allBookings = await _db.getUserBookings(username);
        // Filter to show completed, paid, cancelled, or rejected bookings
        final historyBookings = allBookings.where((booking) {
          final status = booking['status']?.toString().toLowerCase();
          final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
          
          // Show cancelled, rejected, or successfully paid bookings
          return status == 'cancelled' || 
                 status == 'rejected' ||
                 status == 'completed' ||
                 (status == 'approved' && paymentStatus == 'completed') ||
                 (status == 'paid' && paymentStatus == 'completed');
        }).toList();
        
        // Sort by most recent first
        historyBookings.sort((a, b) {
          final aTime = a['createdAt'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp?;
          if (aTime != null && bTime != null) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });
        
        setState(() {
          _historyBookings = historyBookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading booking history: $e');
      setState(() {
        _isLoading = false;
      });
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

  Color _getBookingStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'paid':
        return Colors.green.shade50;
      case 'approved': // For approved+paid bookings
        return Colors.green.shade50;
      case 'cancelled':
        return Colors.orange.shade50;
      case 'rejected':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getBookingStatusTextColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'paid':
        return Colors.green.shade700;
      case 'approved': // For approved+paid bookings
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.orange.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getBookingStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'paid':
        return Icons.check_circle;
      case 'approved': // For approved+paid bookings
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'rejected':
        return Icons.close;
      default:
        return Icons.history;
    }
  }

  String _getBookingStatusText(Map<String, dynamic> booking) {
    final status = booking['status']?.toString().toLowerCase();
    final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
    
    if ((status == 'paid' && paymentStatus == 'completed') || 
        (status == 'approved' && paymentStatus == 'completed')) {
      return 'COMPLETED';
    }
    
    return booking['status']?.toString().toUpperCase() ?? 'UNKNOWN';
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
                                _getBookingStatusText(booking),
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
                  if (booking['paymentStatus'] != null)
                    _buildDetailRow('Payment Status', booking['paymentStatus'].toString()),
                  
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomerAppBar(
        title: 'Booking History',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Booking History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_historyBookings.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No booking history found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your completed and cancelled bookings will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _historyBookings.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final booking = _historyBookings[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getBookingStatusColor(booking['status']),
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
                                      color: _getBookingStatusTextColor(booking['status']).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getBookingStatusIcon(booking['status']),
                                      size: 28,
                                      color: _getBookingStatusTextColor(booking['status']),
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
                                            color: _getBookingStatusTextColor(booking['status']),
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
                                  // Show total price
                                  Text(
                                    'RM${booking['totalPrice']?.toString() ?? '0'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
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
              ),
          ],
        ),
      ),
    );
  }
}
