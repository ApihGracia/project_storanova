import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shared_widgets.dart';
import 'database.dart';
import 'house_details_dialog.dart';

class CustWishlistPage extends StatefulWidget {
  final bool isEmbedded; // Whether this is embedded in another Scaffold
  
  const CustWishlistPage({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<CustWishlistPage> createState() => _CustWishlistPageState();
}

class _CustWishlistPageState extends State<CustWishlistPage> {
  final DatabaseService _db = DatabaseService();
  late Future<List<Map<String, dynamic>>> _wishlistFuture;
  bool _isIndexBuilding = false;

  @override
  void initState() {
    super.initState();
    _wishlistFuture = _loadWishlist();
  }

  Future<List<Map<String, dynamic>>> _loadWishlist() async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username == null) return [];
      final result = await _db.getUserWishlist(username);
      if (mounted) {
        setState(() {
          _isIndexBuilding = false;
        });
      }
      return result;
    } catch (e) {
      print('Error loading wishlist: $e');
      // If index is building, show empty list for now
      if (e.toString().contains('index is currently building')) {
        if (mounted) {
          setState(() {
            _isIndexBuilding = true;
          });
        }
        return [];
      }
      if (mounted) {
        setState(() {
          _isIndexBuilding = false;
        });
      }
      return [];
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

  void _refreshWishlist() {
    if (mounted) {
      setState(() {
        _wishlistFuture = _loadWishlist();
      });
    }
  }

  Future<void> _removeFromWishlist(String houseId) async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username == null) return;
      
      await _db.removeFromWishlist(username: username, houseId: houseId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from wishlist')),
      );
      _refreshWishlist();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showHouseDetails(Map<String, dynamic> wishlistItem) {
    final houseData = wishlistItem['houseData'] as Map<String, dynamic>;
    
    // Create a house object compatible with HouseDetailsDialog
    final house = {
      'id': wishlistItem['houseId'],
      'address': houseData['address'] ?? wishlistItem['houseAddress'] ?? 'No Address',
      'owner': houseData['owner'] ?? houseData['ownerName'] ?? wishlistItem['ownerUsername'] ?? '',
      'ownerUsername': wishlistItem['ownerUsername'],
      'phone': houseData['phone'] ?? '',
      'prices': houseData['prices'] ?? [],
      'availableFrom': houseData['availableFrom'],
      'availableTo': houseData['availableTo'],
      'imageUrls': houseData['imageUrls'] ?? [],
      'imageUrl': houseData['imageUrl'] ?? '',
      'pricePerItem': houseData['pricePerItem'],
      'maxItemQuantity': houseData['maxItemQuantity'],
      'offerPickupService': houseData['offerPickupService'] ?? false,
      'pickupServiceCost': houseData['pickupServiceCost'],
      'paymentMethods': houseData['paymentMethods'] ?? {},
    };
    
    showDialog(
      context: context,
      builder: (context) => HouseDetailsDialog(
        house: house,
        showRemoveFromWishlist: true,
        onRemoveFromWishlist: () => _removeFromWishlist(wishlistItem['houseId']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<Map<String, dynamic>>>(
      future: _wishlistFuture,
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
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshWishlist,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final wishlistItems = snapshot.data ?? [];
          
          if (wishlistItems.isEmpty) {
            if (_isIndexBuilding) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Setting up your wishlist...',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Database indexes are building. This will take a few minutes.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            
            return Column(
              children: [
                // Always show header with refresh button even when empty
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Wishlist (0 items)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _refreshWishlist,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Your wishlist is empty',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Houses you favorite will appear here',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Wishlist (${wishlistItems.length} items)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshWishlist,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: wishlistItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = wishlistItems[index];
                      final houseData = item['houseData'] as Map<String, dynamic>;
                      
                      return Card(
                        elevation: 2,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showHouseDetails(item),
                          child: SizedBox(
                            height: 100, // Fixed height for consistent rows
                            child: Row(
                              children: [
                                // Image section - fills the left side completely
                                Container(
                                  width: 100, // Square dimensions
                                  height: 100,
                                  child: houseData['imageUrls'] != null && 
                                         houseData['imageUrls'] is List && 
                                         (houseData['imageUrls'] as List).isNotEmpty
                                      ? Image.network(
                                          (houseData['imageUrls'] as List).first,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.home, size: 40, color: Colors.blue),
                                          ),
                                        )
                                      : houseData['imageUrl'] != null
                                          ? Image.network(
                                              houseData['imageUrl'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.home, size: 40, color: Colors.blue),
                                              ),
                                            )
                                          : Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.home, size: 40, color: Colors.blue),
                                            ),
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
                                          houseData['address'] ?? item['houseAddress'] ?? 'No Address',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        if (houseData['owner'] != null && houseData['owner'].toString().isNotEmpty)
                                          Text(
                                            'Owner: ${houseData['owner']}',
                                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 1),
                                        // Show new pricing structure if available, fallback to old structure
                                        if (houseData['pricePerItem'] != null && houseData['pricePerItem'].toString().isNotEmpty)
                                          Text(
                                            'RM${houseData['pricePerItem']} per item',
                                            style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                                          )
                                        else if (houseData['prices'] != null && 
                                            houseData['prices'] is List && 
                                            (houseData['prices'] as List).isNotEmpty)
                                          Text(
                                            'From RM${(houseData['prices'] as List).map((p) => p['amount'] is num ? p['amount'] : double.tryParse(p['amount'].toString()) ?? double.infinity).reduce((a, b) => a < b ? a : b)}',
                                            style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                                          ),
                                        const SizedBox(height: 1),
                                        if (houseData['availableFrom'] != null && houseData['availableTo'] != null)
                                          Text(
                                            'Available: ${houseData['availableFrom'].toString().split('T')[0]} to ${houseData['availableTo'].toString().split('T')[0]}',
                                            style: const TextStyle(fontSize: 11, color: Colors.green),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Remove from wishlist button
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: IconButton(
                                    icon: const Icon(Icons.favorite, color: Colors.red),
                                    onPressed: () => _removeFromWishlist(item['houseId']),
                                    tooltip: 'Remove from wishlist',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
      
    // If embedded, just return the content without Scaffold
    if (widget.isEmbedded) {
      return content;
    }
    
    // Otherwise, return full page with navigation
    return Scaffold(
      appBar: CustomerAppBar(title: 'Wishlist'),
      endDrawer: CustomerDrawer(),
      body: content,
      bottomNavigationBar: CustomerNavBar(
        currentIndex: 1, // Wishlist index
        onTap: (index) {
          // Navigation is handled by the shared widget
        },
      ),
    );
  }
}

// Image Slider Widget for multiple images
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