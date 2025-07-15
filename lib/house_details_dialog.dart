import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';
import 'booking_dialog.dart';
import 'profile_validator.dart';
import 'cust_dashboard.dart';

class HouseDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> house;
  final VoidCallback? onRemoveFromWishlist;
  final bool showRemoveFromWishlist;

  const HouseDetailsDialog({
    Key? key, 
    required this.house,
    this.onRemoveFromWishlist,
    this.showRemoveFromWishlist = false,
  }) : super(key: key);

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
    if (!widget.showRemoveFromWishlist) {
      _checkWishlistStatus();
    } else {
      setState(() {
        _isInWishlist = true;
        _isLoading = false;
      });
    }
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
    final owner = house['owner'] ?? '';
    final address = house['address'] ?? '';
    return '${owner}_${address}'.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
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
        if (widget.onRemoveFromWishlist != null) {
          widget.onRemoveFromWishlist!();
        }
      } else {
        await _db.addToWishlist(
          username: username,
          houseId: houseId,
          houseName: widget.house['address'] ?? 'No Address',
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

  void _showBookingDialog() async {
    // Check if profile is complete before allowing booking
    final isProfileComplete = await ProfileValidator.isCustomerProfileComplete();
    if (!isProfileComplete) {
      ProfileValidator.showProfileIncompleteDialog(context, isOwner: false);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => BookingDialog(
        house: widget.house,
        onBookingComplete: () {
          Navigator.of(context).pop(); // Close booking dialog
          Navigator.of(context).pop(); // Close house details dialog
          // Navigate back to home page to refresh it
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const CustHomePage()),
            (route) => false,
          );
        },
      ),
    );
  }

  // Helper function to format date in dd/mm/yyyy format
  String _formatDateFromString(String dateString) {
    try {
      DateTime dateTime = DateTime.parse(dateString);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return dateString.split('T')[0]; // Fallback to original format
    }
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
              Text(widget.house['address'] ?? 'No Address', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
                Text('Available: ${_formatDateFromString(widget.house['availableFrom'].toString())} to ${_formatDateFromString(widget.house['availableTo'].toString())}'),
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
                            onPressed: widget.showRemoveFromWishlist 
                                ? () {
                                    Navigator.of(context).pop();
                                    if (widget.onRemoveFromWishlist != null) {
                                      widget.onRemoveFromWishlist!();
                                    }
                                  }
                                : _toggleWishlist,
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

// Image slider widget
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
