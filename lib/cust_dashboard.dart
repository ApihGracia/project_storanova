import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';
import 'notifications_page.dart';
import 'shared_widgets.dart';
import 'booking_dialog.dart';

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

// House Details Dialog Widget
class HouseDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> house;

  const HouseDetailsDialog({Key? key, required this.house}) : super(key: key);

  @override
  State<HouseDetailsDialog> createState() => _HouseDetailsDialogState();
}

class _HouseDetailsDialogState extends State<HouseDetailsDialog> {
  final DatabaseService _db = DatabaseService();
  bool _isInWishlist = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkWishlistStatus();
  }

  Future<void> _checkWishlistStatus() async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username != null) {
        final houseId = _generateHouseId(widget.house);
        final inWishlist = await _db.isInWishlist(username: username, houseId: houseId);
        setState(() {
          _isInWishlist = inWishlist;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking wishlist: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

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

  String _generateHouseId(Map<String, dynamic> house) {
    if (house['id'] != null) {
      return house['id'];
    }
    final name = house['name'] ?? '';
    final owner = house['owner'] ?? '';
    final address = house['address'] ?? '';
    return '${owner}_${name}_${address}'.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  }

  Future<void> _toggleWishlist() async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username == null) return;
      
      final houseId = _generateHouseId(widget.house);
      
      if (_isInWishlist) {
        await _db.removeFromWishlist(username: username, houseId: houseId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from wishlist')),
        );
      } else {
        await _db.addToWishlist(
          username: username,
          houseId: houseId,
          houseName: widget.house['name'] ?? 'Unnamed House',
          ownerUsername: widget.house['ownerUsername'] ?? widget.house['owner'] ?? '',
          imageUrl: widget.house['imageUrls'] != null && (widget.house['imageUrls'] as List).isNotEmpty
              ? (widget.house['imageUrls'] as List).first
              : widget.house['imageUrl'],
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to wishlist')),
        );
      }
      
      // Update the state
      setState(() {
        _isInWishlist = !_isInWishlist;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showBookingDialog() {
    showDialog(
      context: context,
      builder: (context) => BookingDialog(
        house: widget.house,
        onBookingComplete: () {
          Navigator.of(context).pop(); // Close booking dialog
          Navigator.of(context).pop(); // Close house details dialog
        },
      ),
    );
  }

  List<Widget> _buildPaymentMethodsList(Map<String, dynamic> paymentMethods) {
    List<Widget> methods = [];
    
    if (paymentMethods['cash'] == true) {
      methods.add(const Text('• Cash', style: TextStyle(fontSize: 13)));
    }
    if (paymentMethods['online_banking'] == true) {
      methods.add(const Text('• Online Banking', style: TextStyle(fontSize: 13)));
    }
    if (paymentMethods['ewallet'] == true) {
      methods.add(const Text('• E-Wallet', style: TextStyle(fontSize: 13)));
    }
    
    return methods.isEmpty ? [const Text('• Not specified', style: TextStyle(fontSize: 13, color: Colors.grey))] : methods;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Image slider with arrows ---
              if (widget.house['imageUrls'] != null && widget.house['imageUrls'] is List && (widget.house['imageUrls'] as List).isNotEmpty)
                _ImageSlider(imageUrls: List<String>.from(widget.house['imageUrls'])),
              // Fallback for single image (legacy)
              if ((widget.house['imageUrls'] == null || (widget.house['imageUrls'] is List && (widget.house['imageUrls'] as List).isEmpty)) && widget.house['imageUrl'] != null && widget.house['imageUrl'].toString().isNotEmpty)
                Center(
                  child: GestureDetector(
                    onTap: () => _showFullScreenImage(context, widget.house['imageUrl']),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(widget.house['imageUrl'], width: 250, height: 180, fit: BoxFit.cover),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(widget.house['name'] ?? 'Unnamed House', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 8),
              if (widget.house['owner'] != null && widget.house['owner'].toString().isNotEmpty)
                Text('Owner: ${widget.house['owner']}', style: const TextStyle(fontSize: 15, color: Colors.black87)),
              if (widget.house['phone'] != null && widget.house['phone'].toString().isNotEmpty)
                Text('Phone: ${widget.house['phone']}'),
              // Show new pricing structure
              if (widget.house['pricePerItem'] != null && widget.house['pricePerItem'].toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Price per Item: RM${widget.house['pricePerItem']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    if (widget.house['maxItemQuantity'] != null && widget.house['maxItemQuantity'].toString().isNotEmpty)
                      Text('Max Items: ${widget.house['maxItemQuantity']}'),
                  ],
                ),
              // Show pickup service if offered
              if (widget.house['offerPickupService'] == true && widget.house['pickupServiceCost'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Pickup Service Available: RM${widget.house['pickupServiceCost']}', style: const TextStyle(color: Colors.blue)),
                  ],
                ),
              // Show payment methods
              if (widget.house['paymentMethods'] != null && widget.house['paymentMethods'] is Map)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('Payment Methods:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._buildPaymentMethodsList(widget.house['paymentMethods']),
                  ],
                ),
              // Fallback to old price structure for backward compatibility
              if ((widget.house['pricePerItem'] == null || widget.house['pricePerItem'].toString().isEmpty) && 
                  widget.house['prices'] != null && widget.house['prices'] is List && (widget.house['prices'] as List).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('Prices:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...((widget.house['prices'] as List).map<Widget>((p) {
                      if (p is Map && p['amount'] != null && p['unit'] != null) {
                        return Text('• RM${p['amount']} ${p['unit']}');
                      }
                      return const SizedBox.shrink();
                    }).toList()),
                  ],
                ),
              // Available dates
              if (widget.house['availableFrom'] != null && widget.house['availableTo'] != null)
                Text('Available: ${widget.house['availableFrom'].toString().split('T')[0]} to ${widget.house['availableTo'].toString().split('T')[0]}'),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _isLoading
                        ? const SizedBox(
                            height: 40,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : ElevatedButton.icon(
                            onPressed: _toggleWishlist,
                            icon: Icon(_isInWishlist ? Icons.favorite : Icons.favorite_border),
                            label: Text(_isInWishlist ? 'Remove from Wishlist' : 'Add to Wishlist'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isInWishlist ? Colors.red.shade100 : Colors.blue.shade100,
                              foregroundColor: _isInWishlist ? Colors.red : Colors.blue,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showBookingDialog,
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Book Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                        foregroundColor: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustHomePageState extends State<CustHomePage> {
  int _currentIndex = 0; // Start at "Home"
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

  Color _getBookingStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade100;
      case 'approved':
        return Colors.green.shade100;
      case 'rejected':
        return Colors.red.shade100;
      case 'cancelled':
        return Colors.grey.shade200;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getBookingStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade700;
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'cancelled':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _loadBookings() async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username != null) {
        final bookings = await _db.getUserBookings(username);
        setState(() {
          _bookings = bookings;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomerAppBar(title: 'StoraNova'),
      endDrawer: const CustomerDrawer(),
      body: Padding(
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
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _bookings.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    return Container(
                      width: 280,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getBookingStatusColor(booking['status']),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['houseName'] ?? 'Unnamed House',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: ${booking['status'].toString().toUpperCase()}',
                            style: TextStyle(
                              color: _getBookingStatusTextColor(booking['status']),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Check-in: ${booking['checkIn']?.toString().split('T')[0] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Check-out: ${booking['checkOut']?.toString().split('T')[0] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Total: RM${booking['totalPrice']?.toString() ?? '0'}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 32, thickness: 2),
            ] else if (_isBookingsIndexBuilding) ...[
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
                Row(
                  children: [
                    const Text('Sort by: '),
                    DropdownButton<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(value: 'perDay', child: Text('Price (Low to High)')),
                        DropdownMenuItem(value: 'perWeek', child: Text('Price (High to Low)')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _sortBy = value);
                      },
                    ),
                  ],
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
                      final name = (house['name'] ?? '').toLowerCase();
                      return address.contains(_searchQuery) || name.contains(_searchQuery);
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
                                          house['address'] ?? house['name'] ?? 'Unnamed House',
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
                                            'Available: ${house['availableFrom'].toString().split('T')[0]} to ${house['availableTo'].toString().split('T')[0]}',
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
      ),
      bottomNavigationBar: CustomerNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
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
          'name': data['name'] ?? data['address'] ?? 'Unnamed House', // Use address as name if name is not available
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
}

// Add this widget at the bottom of the file (outside the class)
class _ImageSlider extends StatefulWidget {
  final List<String> imageUrls;
  const _ImageSlider({required this.imageUrls});

  @override
  State<_ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<_ImageSlider> {
  int _currentPage = 0;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (page >= 0 && page < widget.imageUrls.length) {
      _controller.animateToPage(page, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
      setState(() => _currentPage = page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, idx) {
              final url = widget.imageUrls[idx];
              return GestureDetector(
                onTap: () => _showFullScreenImage(context, url),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, width: 250, height: 180, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              left: 0,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 28),
                onPressed: _currentPage > 0 ? () => _goTo(_currentPage - 1) : null,
              ),
            ),
          if (widget.imageUrls.length > 1)
            Positioned(
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 28),
                onPressed: _currentPage < widget.imageUrls.length - 1 ? () => _goTo(_currentPage + 1) : null,
              ),
            ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentPage ? Colors.blue : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _showFullScreenImage(BuildContext context, String url) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Colors.black.withOpacity(0.95),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}