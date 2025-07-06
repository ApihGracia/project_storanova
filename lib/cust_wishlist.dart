import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shared_widgets.dart';
import 'database.dart';

class CustWishlistPage extends StatefulWidget {
  const CustWishlistPage({Key? key}) : super(key: key);

  @override
  State<CustWishlistPage> createState() => _CustWishlistPageState();
}

class _CustWishlistPageState extends State<CustWishlistPage> {
  final DatabaseService _db = DatabaseService();
  late Future<List<Map<String, dynamic>>> _wishlistFuture;

  @override
  void initState() {
    super.initState();
    _wishlistFuture = _loadWishlist();
  }

  Future<List<Map<String, dynamic>>> _loadWishlist() async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username == null) return [];
      return await _db.getUserWishlist(username);
    } catch (e) {
      print('Error loading wishlist: $e');
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
    setState(() {
      _wishlistFuture = _loadWishlist();
    });
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
                // Owner name
                if (wishlistItem['ownerUsername'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      wishlistItem['ownerUsername'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                
                // House image
                if (houseData['imageUrls'] != null && 
                    houseData['imageUrls'] is List && 
                    (houseData['imageUrls'] as List).isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      (houseData['imageUrls'] as List).first,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (houseData['imageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      houseData['imageUrl'],
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // House name
                Text(
                  wishlistItem['houseName'] ?? 'Unnamed House',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 8),
                
                // House details
                if (houseData['address'] != null)
                  Text('Address: ${houseData['address']}'),
                if (houseData['phone'] != null)
                  Text('Phone: ${houseData['phone']}'),
                
                // Prices
                if (houseData['prices'] != null && 
                    houseData['prices'] is List && 
                    (houseData['prices'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text('Prices:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...((houseData['prices'] as List).map<Widget>((p) {
                        if (p is Map && p['amount'] != null && p['unit'] != null) {
                          return Text('• RM${p['amount']} ${p['unit']}');
                        }
                        return const SizedBox.shrink();
                      }).toList()),
                    ],
                  ),
                
                // Available dates
                if (houseData['availableFrom'] != null && houseData['availableTo'] != null)
                  Text(
                    'Available: ${houseData['availableFrom'].toString().split('T')[0]} to ${houseData['availableTo'].toString().split('T')[0]}',
                  ),
                
                const SizedBox(height: 20),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _removeFromWishlist(wishlistItem['houseId']);
                        },
                        icon: const Icon(Icons.favorite),
                        label: const Text('Remove from Wishlist'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomerAppBar(title: 'Wishlist'),
      endDrawer: CustomerDrawer(),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
            return const Center(
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
            );
          }
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Wishlist (${wishlistItems.length} items)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: houseData['imageUrls'] != null && 
                                   houseData['imageUrls'] is List && 
                                   (houseData['imageUrls'] as List).isNotEmpty
                                ? Image.network(
                                    (houseData['imageUrls'] as List).first,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                : houseData['imageUrl'] != null
                                    ? Image.network(
                                        houseData['imageUrl'],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.home, size: 40, color: Colors.blue),
                          ),
                          title: Text(
                            item['houseName'] ?? 'Unnamed House',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item['ownerUsername'] != null)
                                Text('Owner: ${item['ownerUsername']}'),
                              if (houseData['address'] != null)
                                Text(houseData['address']),
                              if (houseData['prices'] != null && 
                                  houseData['prices'] is List && 
                                  (houseData['prices'] as List).isNotEmpty)
                                Text(
                                  'From RM${(houseData['prices'] as List).map((p) => p['amount'] is num ? p['amount'] : double.tryParse(p['amount'].toString()) ?? double.infinity).reduce((a, b) => a < b ? a : b)}',
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () => _removeFromWishlist(item['houseId']),
                          ),
                          onTap: () => _showHouseDetails(item),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: CustomerNavBar(
        currentIndex: 1, // Wishlist index
        onTap: (index) {
          // Navigation is handled by the shared widget
        },
      ),
    );
  }
}