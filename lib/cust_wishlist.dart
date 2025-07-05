import 'package:flutter/material.dart';
import 'shared_widgets.dart';

class CustWishlistPage extends StatefulWidget {
  const CustWishlistPage({Key? key}) : super(key: key);

  @override
  State<CustWishlistPage> createState() => _CustWishlistPageState();
}

class _CustWishlistPageState extends State<CustWishlistPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomerAppBar(title: 'Wishlist'),
      endDrawer: CustomerDrawer(),
      body: const Center(
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
      bottomNavigationBar: CustomerNavBar(
        currentIndex: 1, // Wishlist index
        onTap: (index) {
          // Navigation is handled by the shared widget
        },
      ),
    );
  }
}