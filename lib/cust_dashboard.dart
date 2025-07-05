import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- Added import
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

  @override
  void initState() {
    super.initState();
    _housesFuture = _fetchHouses();
  }

  void _refreshHouses() {
    setState(() {
      _housesFuture = _fetchHouses();
    });
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