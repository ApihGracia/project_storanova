import 'package:flutter/material.dart';
import 'main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- Added import
// StoraNovaNavBar is now available from main.dart
import 'cust_profile.dart';
import 'cust_wishlist.dart';
// import 'package:provider/provider.dart';

void main() {
  // runApp(const MyApp());
  runApp(CustDashboard());
}

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFB4D4FF),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.network(
              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
              width: 50,
              height: 50,
            ),
            const SizedBox(width: 8),
            const Text(
              'StoraNova(Customer)',
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DrawerHeader(
                child: Text('Menu', style: TextStyle(fontSize: 24)),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log Out'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
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
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchHouses(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                          onTap: () {
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
                          },
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
      bottomNavigationBar: StoraNovaNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
          if (index == 0) {
            // Home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CustHomePage()),
            );
          } else if (index == 1) {
            // Wishlist (implement if needed)
            // Navigator.pushReplacement(...)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CustWishlistPage()),
            );
            } else if (index == 2) {
            // Wishlist
            
            // Notification (implement if needed)
            // Navigator.pushReplacement(...)
          } else if (index == 3) {
            // Profile
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchHouses() async {
    // Fetch all houses (no status filter)
    final houseSnapshot = await FirebaseFirestore.instance.collection('Houses').get();
    if (houseSnapshot.docs.isEmpty) return [];

    // For backward compatibility: if 'owner' field is missing or empty, fetch from AppUsers using doc.id (username)
    List<Map<String, dynamic>> houses = [];
    for (var doc in houseSnapshot.docs) {
      final data = doc.data();
      String Name = data['owner'] ?? '';
      if (Name.isEmpty) {
        // Try to fetch from AppUsers using doc.id (username)
        final ownerProfile = await FirebaseFirestore.instance.collection('AppUsers').doc(doc.id).get();
        Name = ownerProfile.data()?['name'] ?? '';
      }
      houses.add({
        'name': data['name'] ?? '',
        'address': data['address'] ?? '',
        'pricePerDay': data['pricePerDay'],
        'pricePerWeek': data['pricePerWeek'],
        'imageUrl': data['imageUrl'] ?? '',
        'imageUrls': data['imageUrls'] ?? [],
        'owner': Name, // Use 'owner' as the key for consistency
        'phone': data['phone'] ?? '',
        'prices': data['prices'] ?? [],
        'availableFrom': data['availableFrom'],
        'availableTo': data['availableTo'],
      });
    }
    return houses;
  }

  Widget _buildServiceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard({required String imageUrl}) {
    return Card(
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
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