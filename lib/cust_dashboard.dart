import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';
import 'notifications_page.dart';
import 'shared_widgets.dart';

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

// Place this function before the _CustHomePageState class so it is in scope for all usages
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

class _CustHomePageState extends State<CustHomePage> {
  int _currentIndex = 0; // Start at "Home"
  String _sortBy = 'perDay'; // 'perDay' or 'perWeek'
  late Future<List<Map<String, dynamic>>> _housesFuture;
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _checkUserBanStatus();
    _housesFuture = _fetchHouses();
    _loadBookings();
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

  Future<bool> _isInWishlist(Map<String, dynamic> house) async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username == null) return false;
      
      // Generate house ID from house data
      final houseId = _generateHouseId(house);
      return await _db.isInWishlist(username: username, houseId: houseId);
    } catch (e) {
      print('Error checking wishlist: $e');
      return false;
    }
  }

  Future<void> _toggleWishlist(Map<String, dynamic> house, bool isCurrentlyInWishlist) async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username == null) return;
      
      final houseId = _generateHouseId(house);
      
      if (isCurrentlyInWishlist) {
        await _db.removeFromWishlist(username: username, houseId: houseId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from wishlist')),
        );
      } else {
        await _db.addToWishlist(
          username: username,
          houseId: houseId,
          houseName: house['name'] ?? 'Unnamed House',
          ownerUsername: house['owner'] ?? '',
          imageUrl: house['imageUrls'] != null && (house['imageUrls'] as List).isNotEmpty
              ? (house['imageUrls'] as List).first
              : house['imageUrl'],
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to wishlist')),
        );
      }
      
      // Refresh the dialog by rebuilding it
      Navigator.of(context).pop();
      _showHouseDetails(house);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showBookingDialog(Map<String, dynamic> house) {
    showDialog(
      context: context,
      builder: (context) => BookingDialog(
        house: house,
        onBookingComplete: () {
          _loadBookings(); // Refresh bookings
          Navigator.of(context).pop(); // Close house details dialog
        },
      ),
    );
  }

  void _showHouseDetails(Map<String, dynamic> house) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (house['owner'] != null && house['owner'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text('${house['owner']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                // --- Image slider with arrows ---
                if (house['imageUrls'] != null && house['imageUrls'] is List && (house['imageUrls'] as List).isNotEmpty)
                  _ImageSlider(imageUrls: List<String>.from(house['imageUrls'])),
                // Fallback for single image (legacy)
                if ((house['imageUrls'] == null || (house['imageUrls'] is List && (house['imageUrls'] as List).isEmpty)) && house['imageUrl'] != null && house['imageUrl'].toString().isNotEmpty)
                  Center(
                    child: GestureDetector(
                      onTap: () => _showFullScreenImage(context, house['imageUrl']),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(house['imageUrl'], width: 250, height: 180, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(house['name'] ?? 'Unnamed House', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 8),
                if (house['owner'] != null && house['owner'].toString().isNotEmpty)
                  Text('Owner: ${house['owner']}', style: const TextStyle(fontSize: 15, color: Colors.black87)),
                if (house['address'] != null && house['address'].toString().isNotEmpty)
                  Text('Address: ${house['address']}'),
                if (house['phone'] != null && house['phone'].toString().isNotEmpty)
                  Text('Phone: ${house['phone']}'),
                // Show all price options if available
                if (house['prices'] != null && house['prices'] is List && (house['prices'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text('Prices:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...((house['prices'] as List).map<Widget>((p) {
                        if (p is Map && p['amount'] != null && p['unit'] != null) {
                          return Text('• RM${p['amount']} ${p['unit']}');
                        }
                        return const SizedBox.shrink();
                      }).toList()),
                    ],
                  ),
                // Available dates
                if (house['availableFrom'] != null && house['availableTo'] != null)
                  Text('Available: ${house['availableFrom'].toString().split('T')[0]} to ${house['availableTo'].toString().split('T')[0]}'),
                const SizedBox(height: 20),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<bool>(
                        future: _isInWishlist(house),
                        builder: (context, snapshot) {
                          final isInWishlist = snapshot.data ?? false;
                          return ElevatedButton.icon(
                            onPressed: () => _toggleWishlist(house, isInWishlist),
                            icon: Icon(isInWishlist ? Icons.favorite : Icons.favorite_border),
                            label: Text(isInWishlist ? 'Remove from Wishlist' : 'Add to Wishlist'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isInWishlist ? Colors.red.shade100 : Colors.blue.shade100,
                              foregroundColor: isInWishlist ? Colors.red : Colors.blue,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showBookingDialog(house),
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
      ),
    );
  }

  String _generateHouseId(Map<String, dynamic> house) {
    // Generate a unique ID based on house data
    final name = house['name'] ?? '';
    final owner = house['owner'] ?? '';
    final address = house['address'] ?? '';
    return '${owner}_${name}_${address}'.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
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
        });
      }
    } catch (e) {
      print('Error loading bookings: $e');
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
            ],
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
                        DropdownMenuItem(value: 'perDay', child: Text('Price per Day')),
                        DropdownMenuItem(value: 'perWeek', child: Text('Price per Week')),
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
                  // Sort by lowest price in prices array (if available)
                  if (_sortBy == 'perDay' || _sortBy == 'perWeek') {
                    sortedHouses.sort((a, b) {
                      final aPrices = (a['prices'] is List && (a['prices'] as List).isNotEmpty)
                          ? (a['prices'] as List).map((p) => p['amount'] is num ? p['amount'] : double.tryParse(p['amount'].toString()) ?? double.infinity).toList()
                          : [double.infinity];
                      final bPrices = (b['prices'] is List && (b['prices'] as List).isNotEmpty)
                          ? (b['prices'] as List).map((p) => p['amount'] is num ? p['amount'] : double.tryParse(p['amount'].toString()) ?? double.infinity).toList()
                          : [double.infinity];
                      final aMin = aPrices.reduce((v, e) => v < e ? v : e);
                      final bMin = bPrices.reduce((v, e) => v < e ? v : e);
                      return aMin.compareTo(bMin);
                    });
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
                        child: ListTile(
                          leading: house['imageUrls'] != null && house['imageUrls'] is List && (house['imageUrls'] as List).isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _showFullScreenImage(context, (house['imageUrls'] as List).first);
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network((house['imageUrls'] as List).first, width: 60, height: 60, fit: BoxFit.cover),
                                  ),
                                )
                              : (house['imageUrl'] != null && house['imageUrl'].toString().isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        _showFullScreenImage(context, house['imageUrl']);
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(house['imageUrl'], width: 60, height: 60, fit: BoxFit.cover),
                                      ),
                                    )
                                  : const Icon(Icons.home, size: 40, color: Colors.blue)),
                          title: Text(house['name'] ?? 'Unnamed House', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (house['prices'] != null && house['prices'] is List && (house['prices'] as List).isNotEmpty)
                                Text('From RM${(house['prices'] as List).map((p) => p['amount'] is num ? p['amount'] : double.tryParse(p['amount'].toString()) ?? '').where((v) => v != '').fold<double?>(null, (min, v) => min == null || (v is num && v < min) ? v : min)}'),
                              if (house['owner'] != null && house['owner'].toString().isNotEmpty)
                                Text('Owner: ${house['owner']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                              if (house['address'] != null && house['address'].toString().isNotEmpty)
                                Text(house['address']),
                            ],
                          ),
                          onTap: () => _showHouseDetails(house),
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
          'name': data['name'] ?? '',
          'address': data['address'] ?? '',
          'pricePerDay': data['pricePerDay'],
          'pricePerWeek': data['pricePerWeek'],
          'imageUrl': data['imageUrl'] ?? '',
          'imageUrls': data['imageUrls'] ?? [],
          'owner': data['owner'] ?? data['ownerName'] ?? '', // Use owner name from approved data
          'phone': data['phone'] ?? '',
          'prices': data['prices'] ?? [],
          'availableFrom': data['availableFrom'],
          'availableTo': data['availableTo'],
          'description': data['description'] ?? '',
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

// Add this widget at the bottom of the file (outside the class)
class BookingDialog extends StatefulWidget {
  final Map<String, dynamic> house;
  final VoidCallback onBookingComplete;

  const BookingDialog({
    Key? key,
    required this.house,
    required this.onBookingComplete,
  }) : super(key: key);

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  String? _selectedPriceOption;
  final _specialRequestsController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;

  @override
  void dispose() {
    _specialRequestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prices = widget.house['prices'] as List? ?? [];
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Book ${widget.house['name'] ?? 'House'}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Price selection
                if (prices.isNotEmpty) ...[
                  const Text('Select Price Option:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('Choose a price option'),
                    value: _selectedPriceOption,
                    items: prices.map<DropdownMenuItem<String>>((price) {
                      if (price is Map && price['amount'] != null && price['unit'] != null) {
                        final option = 'RM${price['amount']} ${price['unit']}';
                        return DropdownMenuItem(value: option, child: Text(option));
                      }
                      return const DropdownMenuItem(value: '', child: Text('Invalid price'));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedPriceOption = value),
                    validator: (value) => value == null || value.isEmpty ? 'Please select a price option' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Check-in date
                const Text('Check-in Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(context, true),
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
                        Text(_checkInDate != null 
                            ? _checkInDate!.toString().split(' ')[0]
                            : 'Select check-in date'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Check-out date
                const Text('Check-out Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(context, false),
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
                        Text(_checkOutDate != null 
                            ? _checkOutDate!.toString().split(' ')[0]
                            : 'Select check-out date'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Total price display
                if (_checkInDate != null && _checkOutDate != null && _selectedPriceOption != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Booking Summary:', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Duration: ${_checkOutDate!.difference(_checkInDate!).inDays} days'),
                        Text('Price: $_selectedPriceOption'),
                        Text('Total: RM${_calculateTotal()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Special requests
                const Text('Special Requests (Optional):', style: TextStyle(fontWeight: FontWeight.w500)),
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

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Submit Booking'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn 
          ? (widget.house['availableFrom'] != null 
              ? DateTime.tryParse(widget.house['availableFrom'].toString()) ?? now
              : now)
          : (_checkInDate?.add(const Duration(days: 1)) ?? now.add(const Duration(days: 1))),
      firstDate: isCheckIn ? now : (_checkInDate ?? now),
      lastDate: widget.house['availableTo'] != null 
          ? DateTime.tryParse(widget.house['availableTo'].toString()) ?? now.add(const Duration(days: 365))
          : now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = picked;
          // Clear check-out if it's before the new check-in date
          if (_checkOutDate != null && _checkOutDate!.isBefore(picked.add(const Duration(days: 1)))) {
            _checkOutDate = null;
          }
        } else {
          _checkOutDate = picked;
        }
      });
    }
  }

  double _calculateTotal() {
    if (_checkInDate == null || _checkOutDate == null || _selectedPriceOption == null) return 0;
    
    final days = _checkOutDate!.difference(_checkInDate!).inDays;
    if (days <= 0) return 0;
    
    // Extract price from selected option (format: "RM123 per day/week")
    final priceMatch = RegExp(r'RM(\d+(?:\.\d+)?)').firstMatch(_selectedPriceOption!);
    if (priceMatch == null) return 0;
    
    final price = double.tryParse(priceMatch.group(1)!) ?? 0;
    
    if (_selectedPriceOption!.contains('per week')) {
      final weeks = (days / 7).ceil();
      return price * weeks;
    } else {
      return price * days;
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_checkInDate == null || _checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select check-in and check-out dates')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get username from email lookup
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      
      if (usersSnapshot.docs.isEmpty) throw Exception('User not found');
      final username = usersSnapshot.docs.first.id;

      final total = _calculateTotal();
      final days = _checkOutDate!.difference(_checkInDate!).inDays;
      
      await _db.createBooking(
        customerUsername: username,
        ownerUsername: widget.house['owner'] ?? '',
        houseId: _generateHouseId(widget.house),
        houseName: widget.house['name'] ?? 'Unnamed House',
        checkIn: _checkInDate!,
        checkOut: _checkOutDate!,
        totalPrice: total,
        priceBreakdown: '$_selectedPriceOption for $days days',
        specialRequests: _specialRequestsController.text.trim().isEmpty 
            ? null 
            : _specialRequestsController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking submitted successfully!')),
      );

      widget.onBookingComplete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting booking: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _generateHouseId(Map<String, dynamic> house) {
    final name = house['name'] ?? '';
    final owner = house['owner'] ?? '';
    final address = house['address'] ?? '';
    return '${owner}_${name}_${address}'.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  }
}