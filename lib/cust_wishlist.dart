import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => WishlistData(),
      child: const MyApp(),
    ),
  );
}

// void main() {
//   runApp(const MyApp());
// }

class WishlistData extends ChangeNotifier {
  final List<WishlistItem> items = [
    WishlistItem(
      itemType: 'Clothes',
      quantity: 2,
      sentDate: '08/07/25',
      pickUpDate: '10/10/25',
      paymentOption: 'Cash',
      status: 'Approved',
    ),
    WishlistItem(
      itemType: 'Vehicle',
      quantity: 2,
      sentDate: '08/07/25',
      pickUpDate: '10/10/25',
      paymentOption: 'Cash',
      status: 'Pending',
    ),
    WishlistItem(
      itemType: 'Bed',
      quantity: 2,
      sentDate: '08/07/25',
      pickUpDate: '10/10/25',
      paymentOption: 'Cash',
      status: 'Approved',
    ),
    WishlistItem(
      itemType: 'Clothes',
      quantity: 2,
      sentDate: '08/07/25',
      pickUpDate: '10/10/25',
      paymentOption: 'Cash',
      status: 'Pending',
    ),
  ];
}

class WishlistItem {
  WishlistItem({
    required this.itemType,
    required this.quantity,
    required this.sentDate,
    required this.pickUpDate,
    required this.paymentOption,
    required this.status,
  });

  final String itemType;
  final int quantity;
  final String sentDate;
  final String pickUpDate;
  final String paymentOption;
  final String status;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wishlist App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFB0E2FF),
      ),
      home: const WishlistScreen(),
    );
  }
}

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4682B4),
        title: const Text('Wishlist', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
        centerTitle: true,
      ),
      body: Consumer<WishlistData>(
        builder: (context, wishlistData, child) {
          return ListView.builder(
            itemCount: wishlistData.items.length,
            itemBuilder: (context, index) {
              return WishlistItemCard(item: wishlistData.items[index]);
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF4682B4),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Wishlist'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notification'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class WishlistItemCard extends StatelessWidget {
  const WishlistItemCard({super.key, required this.item});

  final WishlistItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: const Color(0xFFADD8E6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Image.network(
                    'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Items Type', item.itemType),
                    _buildInfoRow('Quantity', item.quantity.toString()),
                    _buildInfoRow('Sent Date', item.sentDate),
                    _buildInfoRow('Pick Up Date', item.pickUpDate),
                    _buildInfoRow('Payment Option', item.paymentOption),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: _buildStatusButton(item.status),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 5),
        Text(value),
      ],
    );
  }

  Widget _buildStatusButton(String status) {
    Color buttonColor;
    Color textColor;

    switch (status) {
      case 'Approved':
        buttonColor = Colors.green;
        textColor = Colors.white;
        break;
      case 'Pending':
        buttonColor = Colors.red;
        textColor = Colors.white;
        break;
      default:
        buttonColor = Colors.grey;
        textColor = Colors.black;
        break;
    }

    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(status, style: TextStyle(color: textColor)),
    );
  }
}