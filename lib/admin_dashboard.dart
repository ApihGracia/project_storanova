import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';
import 'main.dart';

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HouseApplicationsPage(),
          AdminProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFFB4D4FF),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Applications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }
}

class HouseApplicationsPage extends StatefulWidget {
  @override
  _HouseApplicationsPageState createState() => _HouseApplicationsPageState();
}

class _HouseApplicationsPageState extends State<HouseApplicationsPage> {
  final DatabaseService _dbService = DatabaseService();
  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> applications;
      if (_selectedFilter == 'all') {
        applications = await _dbService.getHouseApplications();
      } else {
        applications = await _dbService.getHouseApplications(status: _selectedFilter);
      }
      
      setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading applications: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Filter dropdown
          Row(
            children: [
              const Text('Filter: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                    _loadApplications();
                  },
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Applications')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadApplications,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Applications list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _applications.isEmpty
                    ? Center(
                        child: Text(
                          'No ${_selectedFilter == 'all' ? '' : _selectedFilter} applications found',
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _applications.length,
                        itemBuilder: (context, index) {
                          final application = _applications[index];
                          return ApplicationCard(
                            application: application,
                            onReview: _reviewApplication,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewApplication(String applicationId, String status, String? comments) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _dbService.reviewHouseApplication(
        applicationId: applicationId,
        status: status,
        reviewedBy: currentUser.email ?? 'admin',
        reviewComments: comments,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Application ${status.toLowerCase()} successfully')),
      );

      _loadApplications(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reviewing application: $e')),
      );
    }
  }
}

class ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> application;
  final Function(String, String, String?) onReview;

  const ApplicationCard({
    Key? key,
    required this.application,
    required this.onReview,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = application['status'] as String;
    final submittedAt = DateTime.parse(application['submittedAt']);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    application['address'] ?? 'No address',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Owner: ${application['ownerName'] ?? 'Unknown'}'),
            Text('Phone: ${application['phone'] ?? 'N/A'}'),
            Text('Email: ${application['ownerEmail'] ?? 'N/A'}'),
            Text('Submitted: ${_formatDate(submittedAt)}'),
            
            if (application['description'] != null && application['description'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Description: ${application['description']}'),
            ],
            
            if (application['reviewComments'] != null && application['reviewComments'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Review Comments: ${application['reviewComments']}', 
                   style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            
            const SizedBox(height: 12),
            
            // Action buttons for pending applications
            if (status == 'pending') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showReviewDialog(context, true),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Approve', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showReviewDialog(context, false),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text('Reject', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ],
            
            // View details button
            TextButton(
              onPressed: () => _showApplicationDetails(context),
              child: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, bool isApproval) {
    final TextEditingController commentsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApproval ? 'Approve Application' : 'Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to ${isApproval ? 'approve' : 'reject'} this application?'),
            const SizedBox(height: 16),
            TextField(
              controller: commentsController,
              decoration: const InputDecoration(
                labelText: 'Comments (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onReview(
                application['id'],
                isApproval ? 'approved' : 'rejected',
                commentsController.text.trim().isEmpty ? null : commentsController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproval ? Colors.green : Colors.red,
            ),
            child: Text(
              isApproval ? 'Approve' : 'Reject',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showApplicationDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Application Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow('Address', application['address'] ?? 'N/A'),
                      _DetailRow('Owner', application['ownerName'] ?? 'N/A'),
                      _DetailRow('Username', application['ownerUsername'] ?? 'N/A'),
                      _DetailRow('Email', application['ownerEmail'] ?? 'N/A'),
                      _DetailRow('Phone', application['phone'] ?? 'N/A'),
                      _DetailRow('Available From', _formatDate(DateTime.parse(application['availableFrom']))),
                      _DetailRow('Available To', _formatDate(DateTime.parse(application['availableTo']))),
                      _DetailRow('Status', application['status'] ?? 'N/A'),
                      _DetailRow('Submitted', _formatDate(DateTime.parse(application['submittedAt']))),
                      
                      if (application['description'] != null && application['description'].isNotEmpty)
                        _DetailRow('Description', application['description']),
                      
                      if (application['reviewedAt'] != null) ...[
                        _DetailRow('Reviewed At', _formatDate(DateTime.parse(application['reviewedAt']))),
                        _DetailRow('Reviewed By', application['reviewedBy'] ?? 'N/A'),
                      ],
                      
                      if (application['reviewComments'] != null && application['reviewComments'].isNotEmpty)
                        _DetailRow('Review Comments', application['reviewComments']),
                      
                      // Prices
                      if (application['prices'] != null && (application['prices'] as List).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Pricing:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...(application['prices'] as List).map((price) => Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 4),
                          child: Text('• RM${price['amount']} ${price['unit']}'),
                        )),
                      ],
                      
                      // Images
                      if (application['imageUrls'] != null && (application['imageUrls'] as List).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('House Images:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (application['imageUrls'] as List).map<Widget>((imageUrl) {
                            return GestureDetector(
                              onTap: () => _showFullScreenImage(context, imageUrl),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                  image: DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.black.withOpacity(0.2),
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _DetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) => GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: Image.network(imageUrl, fit: BoxFit.contain),
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
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor = Colors.white;
    
    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange;
        break;
      case 'approved':
        backgroundColor = Colors.green;
        break;
      case 'rejected':
        backgroundColor = Colors.red;
        break;
      default:
        backgroundColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class AdminProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Admin Profile',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
