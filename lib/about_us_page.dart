import 'package:flutter/material.dart';
import 'shared_widgets.dart';

class AboutUsPage extends StatelessWidget {
  final String userRole; // 'customer' or 'owner'
  
  const AboutUsPage({Key? key, required this.userRole}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget appBar;
    
    // Choose appropriate navigation based on user role
    switch (userRole.toLowerCase()) {
      case 'owner':
        appBar = OwnerAppBar(title: 'About Us', showBackButton: true, showMenuIcon: false);
        break;
      default: // customer
        appBar = CustomerAppBar(title: 'About Us', showBackButton: true, showMenuIcon: false);
        break;
    }

    return Scaffold(
      appBar: appBar as PreferredSizeWidget,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Info Card
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo and Title
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storage,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'StoraNova',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                            Text(
                              'Smart Storage Solutions',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // About Section
                    const Text(
                      'About StoraNova',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'StoraNova is a revolutionary storage rental platform that connects homeowners with available storage space to customers who need temporary storage solutions. Our platform makes it easy and convenient for both parties to find exactly what they need.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Mission Section
                    const Text(
                      'Our Mission',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To provide a secure, convenient, and affordable storage solution that maximizes the use of existing spaces while creating earning opportunities for homeowners.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Features Card
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Key Features',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildFeatureItem(
                      Icons.home,
                      'Space Rental',
                      'Rent out your unused storage space to earn extra income',
                    ),
                    _buildFeatureItem(
                      Icons.search,
                      'Easy Discovery',
                      'Find storage spaces near you with our smart search system',
                    ),
                    _buildFeatureItem(
                      Icons.security,
                      'Secure Platform',
                      'Safe and secure transactions with user verification',
                    ),
                    _buildFeatureItem(
                      Icons.payment,
                      'Flexible Payment',
                      'Multiple payment options including cash and online payments',
                    ),
                    _buildFeatureItem(
                      Icons.local_shipping,
                      'Pickup Service',
                      'Optional pickup and delivery service for convenience',
                    ),
                    _buildFeatureItem(
                      Icons.support_agent,
                      '24/7 Support',
                      'Round-the-clock customer support for all your needs',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Company Info Card
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Company Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildInfoRow('Founded', '2024'),
                    _buildInfoRow('Version', '1.0.0'),
                    _buildInfoRow('Platform', 'Mobile Application'),
                    _buildInfoRow('Service Type', 'Storage Rental Platform'),
                    
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Thank you for choosing StoraNova! We are committed to providing you with the best storage rental experience.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1976D2),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const Text(': '),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
