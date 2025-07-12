import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';
import 'shared_widgets.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentIndex = 0;
  final GlobalKey<_StatisticsPageState> _statisticsKey = GlobalKey<_StatisticsPageState>();

  void _refreshStatistics() {
    _statisticsKey.currentState?._loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    // Define titles for each page
    final List<String> pageTitles = [
      'Application List',
      'User Management',
      'Appeal Management',
      'Statistics',
    ];

    return Scaffold(
      appBar: AdminAppBar(title: pageTitles[_currentIndex]),
      endDrawer: const AdminDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HouseApplicationsPage(),
          UserManagementPage(onDataChanged: _refreshStatistics),
          AppealsManagementPage(),
          StatisticsPage(key: _statisticsKey),
        ],
      ),
      bottomNavigationBar: AdminNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
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
                      
                      // Proof of Ownership
                      if (application['proofOfOwnershipUrl'] != null && application['proofOfOwnershipUrl'].isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Proof of Ownership:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showFullScreenImage(context, application['proofOfOwnershipUrl']),
                          child: Container(
                            width: 150,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                              color: Colors.grey.shade50,
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description, size: 40, color: Colors.blue),
                                SizedBox(height: 4),
                                Text('Ownership Document', style: TextStyle(fontSize: 12)),
                                Text('(Tap to view)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
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
  final Color? color;

  const _StatusChip({required this.status, this.color});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor = Colors.white;
    
    if (color != null) {
      backgroundColor = color!;
    } else {
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

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  
  // Statistics data
  int _totalUsers = 0;
  int _totalCustomers = 0;
  int _totalOwners = 0;
  int _totalHouses = 0;
  int _activeHouses = 0;
  int _bannedUsers = 0;
  int _bannedHouses = 0;
  int _unavailableHouses = 0;
  int _pendingApplications = 0;
  int _approvedApplications = 0;
  int _rejectedApplications = 0;
  int _pendingAppeals = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get user statistics
      final allUsers = await _dbService.getAllUsers();
      final filteredUsers = allUsers.where((user) {
        final role = user['role']?.toString().toLowerCase() ?? '';
        return role == 'customer' || role == 'owner';
      }).toList();

      final customers = filteredUsers.where((user) => 
          (user['role']?.toString().toLowerCase() ?? '') == 'customer').toList();
      final owners = filteredUsers.where((user) => 
          (user['role']?.toString().toLowerCase() ?? '') == 'owner').toList();
      
      final bannedUsers = filteredUsers.where((user) => 
          user['isBanned'] == true).length;

      // Get application statistics
      final allApplications = await _dbService.getHouseApplications();
      final pendingApps = allApplications.where((app) => app['status'] == 'pending').length;
      final approvedApps = allApplications.where((app) => app['status'] == 'approved').length;
      final rejectedApps = allApplications.where((app) => app['status'] == 'rejected').length;

      // Get house statistics from approved houses collection
      final approvedHouses = await _dbService.getApprovedHouses();
      final totalHouses = approvedHouses.length;
      final activeHouses = approvedHouses.where((house) => 
          (house['isAvailable'] == true) && 
          !(house['isHouseBanned'] == true)).length;
      final houseBans = approvedHouses.where((house) => 
          house['isHouseBanned'] == true).length;
      final unavailableHouses = approvedHouses.where((house) => 
          (house['isAvailable'] == false) && 
          !(house['isHouseBanned'] == true)).length;

      // Get appeal statistics
      final allAppeals = await _dbService.getAllAppeals();
      final pendingAppeals = allAppeals.where((appeal) => appeal['status'] == 'pending').length;

      setState(() {
        _totalUsers = filteredUsers.length;
        _totalCustomers = customers.length;
        _totalOwners = owners.length;
        _totalHouses = totalHouses;
        _activeHouses = activeHouses;
        _bannedUsers = bannedUsers;
        _bannedHouses = houseBans;
        _unavailableHouses = unavailableHouses;
        _pendingApplications = pendingApps;
        _approvedApplications = approvedApps;
        _rejectedApplications = rejectedApps;
        _pendingAppeals = pendingAppeals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading statistics: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.bar_chart, size: 32, color: Colors.blue),
                        const SizedBox(width: 12),
                        const Text(
                          'Platform Statistics',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loadStatistics,
                          tooltip: 'Refresh Statistics',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // User Statistics
                    _buildStatisticSection(
                      'User Statistics',
                      Icons.people,
                      Colors.blue,
                      [
                        _StatisticCard(
                          title: 'Total Users',
                          value: _totalUsers.toString(),
                          icon: Icons.group,
                          color: Colors.blue,
                        ),
                        _StatisticCard(
                          title: 'Customers',
                          value: _totalCustomers.toString(),
                          icon: Icons.person,
                          color: Colors.green,
                        ),
                        _StatisticCard(
                          title: 'Owners',
                          value: _totalOwners.toString(),
                          icon: Icons.home_work,
                          color: Colors.orange,
                        ),
                        _StatisticCard(
                          title: 'Banned Users',
                          value: _bannedUsers.toString(),
                          icon: Icons.block,
                          color: Colors.red,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // House Statistics
                    _buildStatisticSection(
                      'House Statistics',
                      Icons.home,
                      Colors.green,
                      [
                        _StatisticCard(
                          title: 'Total Houses',
                          value: _totalHouses.toString(),
                          icon: Icons.home,
                          color: Colors.blue,
                        ),
                        _StatisticCard(
                          title: 'Active Houses',
                          value: _activeHouses.toString(),
                          icon: Icons.home,
                          color: Colors.green,
                        ),
                        _StatisticCard(
                          title: 'Banned Houses',
                          value: _bannedHouses.toString(),
                          icon: Icons.home_outlined,
                          color: Colors.red,
                        ),
                        _StatisticCard(
                          title: 'Unavailable Houses',
                          value: _unavailableHouses.toString(),
                          icon: Icons.visibility_off,
                          color: Colors.orange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Application Statistics
                    _buildStatisticSection(
                      'Application Statistics',
                      Icons.assignment,
                      Colors.orange,
                      [
                        _StatisticCard(
                          title: 'Pending Applications',
                          value: _pendingApplications.toString(),
                          icon: Icons.pending,
                          color: Colors.orange,
                        ),
                        _StatisticCard(
                          title: 'Approved Applications',
                          value: _approvedApplications.toString(),
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                        _StatisticCard(
                          title: 'Rejected Applications',
                          value: _rejectedApplications.toString(),
                          icon: Icons.cancel,
                          color: Colors.red,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Appeal Statistics
                    _buildStatisticSection(
                      'Appeal Statistics',
                      Icons.gavel,
                      Colors.purple,
                      [
                        _StatisticCard(
                          title: 'Pending Appeals',
                          value: _pendingAppeals.toString(),
                          icon: Icons.gavel,
                          color: Colors.purple,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatisticSection(String title, IconData icon, Color color, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flash_on, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to pending applications (index 0)
                      final adminState = context.findAncestorStateOfType<_AdminHomePageState>();
                      adminState?.setState(() {
                        adminState._currentIndex = 0;
                      });
                    },
                    icon: const Icon(Icons.pending_actions, color: Colors.white),
                    label: const Text('Pending Apps', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to pending appeals (index 2)
                      final adminState = context.findAncestorStateOfType<_AdminHomePageState>();
                      adminState?.setState(() {
                        adminState._currentIndex = 2;
                      });
                    },
                    icon: const Icon(Icons.gavel, color: Colors.white),
                    label: const Text('Pending Appeals', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to user management (index 1)
                  final adminState = context.findAncestorStateOfType<_AdminHomePageState>();
                  adminState?.setState(() {
                    adminState._currentIndex = 1;
                  });
                },
                icon: const Icon(Icons.people, color: Colors.white),
                label: const Text('Manage Users', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatisticCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatisticCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class UserManagementPage extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const UserManagementPage({Key? key, this.onDataChanged}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all users first
      List<Map<String, dynamic>> users = await _dbService.getAllUsers();
      
      // Filter out admin users - we only want customers and owners
      users = users.where((user) {
        final role = user['role']?.toString().toLowerCase() ?? '';
        return role == 'customer' || role == 'owner';
      }).toList();
      
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
      _filterUsers();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e')),
      );
    }
  }

  void _filterUsers() {
    List<Map<String, dynamic>> filtered = List.from(_allUsers);
    
    // Apply role filter
    if (_selectedFilter != 'all') {
      filtered = filtered.where((user) {
        final role = user['role']?.toString().toLowerCase() ?? '';
        return role == _selectedFilter;
      }).toList();
    }
    
    // Apply search filter
    final searchTerm = _searchController.text.toLowerCase().trim();
    if (searchTerm.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final username = (user['username'] ?? user['id'] ?? '').toString().toLowerCase();
        return name.contains(searchTerm) || username.contains(searchTerm);
      }).toList();
    }
    
    // Sort alphabetically by name
    filtered.sort((a, b) {
      final nameA = (a['name'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });
    
    setState(() {
      _filteredUsers = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or username...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Filter and refresh row
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
                    _filterUsers();
                  },
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'owner', child: Text('Owners')),
                    DropdownMenuItem(value: 'customer', child: Text('Customers')),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadUsers,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Users list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No users found matching "${_searchController.text}"'
                                  : 'No ${_selectedFilter == 'all' ? '' : _selectedFilter} users found',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return CompactUserCard(
                            user: user,
                            onTap: () => _showUserDetails(user),
                            onBanUser: _banUser,
                            onBanHouse: _banHouse,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => UserDetailsDialog(
        user: user,
        onBanUser: _banUser,
        onBanHouse: _banHouse,
        onUpdate: _loadUsers,
      ),
    );
  }

  Future<void> _banUser(String username, String name, bool isBanned, String? reason) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _dbService.updateUserBanStatus(
        username: username,
        isBanned: isBanned,
        banReason: reason,
        bannedBy: currentUser.email ?? 'admin',
      );

      // Send notification to user
      if (isBanned && reason != null) {
        await _dbService.addNotification(
          username: username,
          title: 'Account Banned',
          message: 'Your account has been banned. Reason: $reason',
          type: 'ban',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${isBanned ? 'banned' : 'unbanned'} successfully')),
      );

      _loadUsers(); // Refresh the list
      widget.onDataChanged?.call(); // Refresh statistics if needed
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user status: $e')),
      );
    }
  }

  Future<void> _banHouse(String ownerUsername, String ownerName, bool isHouseBanned, String? reason) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _dbService.updateHouseBanStatus(
        ownerUsername: ownerUsername,
        isHouseBanned: isHouseBanned,
        houseBanReason: reason,
        bannedBy: currentUser.email ?? 'admin',
      );

      // Send notification to owner
      if (isHouseBanned && reason != null) {
        await _dbService.addNotification(
          username: ownerUsername,
          title: 'House Banned',
          message: 'Your house has been banned from the platform. Reason: $reason',
          type: 'ban',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('House ${isHouseBanned ? 'banned' : 'unbanned'} successfully')),
      );

      _loadUsers(); // Refresh the list
      widget.onDataChanged?.call(); // Refresh statistics
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating house status: $e')),
      );
    }
  }
}

// Compact user card for the list view
class CompactUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  final Function(String, String, bool, String?) onBanUser;
  final Function(String, String, bool, String?) onBanHouse;

  const CompactUserCard({
    Key? key,
    required this.user,
    required this.onTap,
    required this.onBanUser,
    required this.onBanHouse,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = user['name'] ?? 'No name';
    final username = user['username'] ?? user['id'] ?? 'Unknown';
    final role = (user['role'] ?? 'customer').toString().toUpperCase();
    final isBanned = user['isBanned'] ?? false;
    final isOwner = (user['role'] ?? '').toString().toLowerCase() == 'owner';
    final isHouseBanned = user['isHouseBanned'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Profile avatar placeholder
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                backgroundImage: user['profileImageUrl'] != null 
                    ? NetworkImage(user['profileImageUrl']) 
                    : null,
                child: user['profileImageUrl'] == null 
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@$username',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: role == 'OWNER' ? Colors.blue[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: role == 'OWNER' ? Colors.blue[800] : Colors.green[800],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Status indicators and action button
              Column(
                children: [
                  // Status chips
                  if (isBanned) ...[
                    const _StatusChip(status: 'banned', color: Colors.red),
                    const SizedBox(height: 4),
                  ],
                  if (isOwner && isHouseBanned) ...[
                    const _StatusChip(status: 'house banned', color: Colors.orange),
                    const SizedBox(height: 4),
                  ],
                  if (!isBanned && !isHouseBanned)
                    const _StatusChip(status: 'active', color: Colors.green),
                  
                  // Quick ban button
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 80,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () => _showQuickBanDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBanned ? Colors.green : Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        isBanned ? 'Unban' : 'Ban',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickBanDialog(BuildContext context) {
    final isBanned = user['isBanned'] ?? false;
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isBanned ? 'Unban' : 'Ban'} User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to ${isBanned ? 'unban' : 'ban'} ${user['name'] ?? 'this user'}?'),
            if (!isBanned) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!isBanned && reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason for banning')),
                );
                return;
              }
              
              Navigator.of(context).pop();
              onBanUser(
                user['username'] ?? user['id'],
                user['name'] ?? 'Unknown',
                !isBanned,
                reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isBanned ? Colors.green : Colors.red,
            ),
            child: Text(
              isBanned ? 'UNBAN' : 'BAN',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Detailed user view dialog
class UserDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(String, String, bool, String?) onBanUser;
  final Function(String, String, bool, String?) onBanHouse;
  final VoidCallback onUpdate;

  const UserDetailsDialog({
    Key? key,
    required this.user,
    required this.onBanUser,
    required this.onBanHouse,
    required this.onUpdate,
  }) : super(key: key);

  @override
  _UserDetailsDialogState createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<UserDetailsDialog> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, dynamic>? _houseData;
  bool _loadingHouse = false;

  @override
  void initState() {
    super.initState();
    _loadHouseData();
  }

  Future<void> _loadHouseData() async {
    final isOwner = (widget.user['role'] ?? '').toString().toLowerCase() == 'owner';
    if (isOwner) {
      setState(() {
        _loadingHouse = true;
      });
      
      try {
        final username = widget.user['username'] ?? widget.user['id'];
        if (username != null) {
          final houseData = await _dbService.getApprovedHouseByOwner(username);
          setState(() {
            _houseData = houseData;
            _loadingHouse = false;
          });
        }
      } catch (e) {
        setState(() {
          _loadingHouse = false;
        });
        print('Error loading house data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name'] ?? 'No name';
    final username = widget.user['username'] ?? widget.user['id'] ?? 'Unknown';
    final email = widget.user['email'] ?? 'N/A';
    final role = (widget.user['role'] ?? 'customer').toString().toUpperCase();
    final isBanned = widget.user['isBanned'] ?? false;
    final isOwner = (widget.user['role'] ?? '').toString().toLowerCase() == 'owner';
    final isHouseBanned = widget.user['isHouseBanned'] ?? false;
    final phone = widget.user['phone'] ?? 'N/A';
    final address = widget.user['address'] ?? 'N/A';
    final banReason = widget.user['banReason'];
    final houseBanReason = widget.user['houseBanReason'];
    final hasHouse = _houseData != null;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'User Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile section
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: widget.user['profileImageUrl'] != null 
                                ? NetworkImage(widget.user['profileImageUrl']) 
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '@$username',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Basic info
                    _buildInfoSection('Basic Information', [
                      _buildInfoRow('Email', email),
                      _buildInfoRow('Phone', phone),
                      if (isOwner) _buildInfoRow('Address', address),
                      _buildInfoRow('Role', role),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    // Status section
                    _buildInfoSection('Account Status', [
                      _buildStatusRow('Account Status', isBanned ? 'BANNED' : 'ACTIVE', 
                          isBanned ? Colors.red : Colors.green),
                      if (isOwner)
                        _buildStatusRow('House Status', 
                            hasHouse ? (isHouseBanned ? 'BANNED' : 'ACTIVE') : 'NO HOUSE', 
                            hasHouse ? (isHouseBanned ? Colors.orange : Colors.green) : Colors.grey),
                    ]),
                    
                    // House information for owners
                    if (isOwner && _loadingHouse)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    
                    if (isOwner && hasHouse && !_loadingHouse) ...[
                      const SizedBox(height: 16),
                      _buildInfoSection('House Information', [
                        _buildInfoRow('House Address', _houseData!['address'] ?? 'N/A'),
                        _buildInfoRow('Description', _houseData!['description'] ?? 'N/A'),
                        _buildInfoRow('Available From', _houseData!['availableFrom'] != null 
                            ? _formatDate(_houseData!['availableFrom']) : 'N/A'),
                        _buildInfoRow('Available To', _houseData!['availableTo'] != null 
                            ? _formatDate(_houseData!['availableTo']) : 'N/A'),
                        _buildInfoRow('House Phone', _houseData!['phone'] ?? 'N/A'),
                        _buildInfoRow('Approved At', _houseData!['approvedAt'] != null 
                            ? _formatDate(_houseData!['approvedAt']) : 'N/A'),
                        _buildInfoRow('Approved By', _houseData!['approvedBy'] ?? 'N/A'),
                      ]),
                      
                      // Pricing information
                      if (_houseData!['prices'] != null && (_houseData!['prices'] as List).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildInfoSection('Pricing Information', [
                          ...((_houseData!['prices'] as List).map<Widget>((price) => 
                            _buildInfoRow('• ${price['unit']}', 'RM${price['amount']}')
                          ).toList()),
                        ]),
                      ],
                      
                      // House images
                      if (_houseData!['imageUrls'] != null && (_houseData!['imageUrls'] as List).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'House Images',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (_houseData!['imageUrls'] as List).map<Widget>((imageUrl) {
                                  return GestureDetector(
                                    onTap: () => _showFullScreenImage(context, imageUrl),
                                    child: Container(
                                      width: 80,
                                      height: 80,
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
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    
                    // Ban reasons
                    if (banReason != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoSection('Ban Information', [
                        _buildInfoRow('Ban Reason', banReason),
                        if (widget.user['bannedBy'] != null)
                          _buildInfoRow('Banned By', widget.user['bannedBy']),
                        if (widget.user['banDate'] != null)
                          _buildInfoRow('Ban Date', _formatDate(widget.user['banDate'])),
                      ]),
                    ],
                    
                    if (houseBanReason != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoSection('House Ban Information', [
                        _buildInfoRow('House Ban Reason', houseBanReason),
                        if (widget.user['houseBannedBy'] != null)
                          _buildInfoRow('House Banned By', widget.user['houseBannedBy']),
                        if (widget.user['houseBanDate'] != null)
                          _buildInfoRow('House Ban Date', _formatDate(widget.user['houseBanDate'])),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
            
            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showBanDialog(context, false),
                      icon: Icon(isBanned ? Icons.check : Icons.block, color: Colors.white),
                      label: Text(
                        isBanned ? 'Unban User' : 'Ban User',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBanned ? Colors.green : Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasHouse ? () => _showBanDialog(context, true) : null,
                        icon: Icon(
                          isHouseBanned ? Icons.home : Icons.home_outlined,
                          color: hasHouse ? Colors.white : Colors.grey,
                        ),
                        label: Text(
                          isHouseBanned ? 'Unban House' : 'Ban House',
                          style: TextStyle(color: hasHouse ? Colors.white : Colors.grey),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasHouse 
                              ? (isHouseBanned ? Colors.green : Colors.orange)
                              : Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  void _showBanDialog(BuildContext context, bool isHouseBan) {
    final TextEditingController reasonController = TextEditingController();
    final isCurrentlyBanned = isHouseBan ? (widget.user['isHouseBanned'] ?? false) : (widget.user['isBanned'] ?? false);
    final action = isCurrentlyBanned ? 'unban' : 'ban';
    final target = isHouseBan ? 'house' : 'user';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.toUpperCase()} ${target.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to $action this $target?'),
            if (!isCurrentlyBanned) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!isCurrentlyBanned && reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason for banning')),
                );
                return;
              }
              
              Navigator.of(context).pop(); // Close ban dialog
              Navigator.of(context).pop(); // Close details dialog
              
              if (isHouseBan) {
                widget.onBanHouse(
                  widget.user['username'] ?? widget.user['id'],
                  widget.user['name'] ?? 'Unknown',
                  !isCurrentlyBanned,
                  reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                );
              } else {
                widget.onBanUser(
                  widget.user['username'] ?? widget.user['id'],
                  widget.user['name'] ?? 'Unknown',
                  !isCurrentlyBanned,
                  reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                );
              }
              
              widget.onUpdate(); // Refresh the user list
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyBanned ? Colors.green : Colors.red,
            ),
            child: Text(
              action.toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
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

class AppealsManagementPage extends StatefulWidget {
  @override
  _AppealsManagementPageState createState() => _AppealsManagementPageState();
}

class _AppealsManagementPageState extends State<AppealsManagementPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _appeals = [];
  bool _isLoading = true;
  String _selectedFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadAppeals();
  }

  Future<void> _loadAppeals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> appeals;
      if (_selectedFilter == 'all') {
        appeals = await _dbService.getAllAppeals();
      } else {
        appeals = await _dbService.getAllAppeals(status: _selectedFilter);
      }

      setState(() {
        _appeals = appeals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading appeals: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appeals Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Filter: '),
                    DropdownButton<String>(
                      value: _selectedFilter,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedFilter = value;
                          });
                          _loadAppeals();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Appeals')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                    ),
                    const Spacer(),
                    Text('Total: ${_appeals.length}'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _appeals.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.gavel, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No appeals found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _appeals.length,
                        itemBuilder: (context, index) {
                          final appeal = _appeals[index];
                          return AppealCard(
                            appeal: appeal,
                            onReview: _reviewAppeal,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewAppeal(Map<String, dynamic> appeal, String status, String? comments) async {
    try {
      await _dbService.reviewAppeal(
        appealId: appeal['id'],
        status: status,
        reviewedBy: 'admin', // You might want to get the actual admin username
        reviewComments: comments,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appeal ${status.toLowerCase()} successfully')),
      );

      _loadAppeals(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reviewing appeal: $e')),
      );
    }
  }
}

class AppealCard extends StatelessWidget {
  final Map<String, dynamic> appeal;
  final Function(Map<String, dynamic>, String, String?) onReview;

  const AppealCard({
    Key? key,
    required this.appeal,
    required this.onReview,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = appeal['status'] as String;
    final submittedAt = DateTime.parse(appeal['submittedAt']);
    final banType = appeal['banType'] as String;
    
    Color statusColor;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  banType == 'user' ? Icons.person : Icons.home,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  '${appeal['username']} - ${banType == 'house' ? 'HOUSE' : 'USER'} Ban Appeal',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Appeal Reason:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(appeal['appealReason'] ?? ''),
            const SizedBox(height: 12),
            Text(
              'Submitted: ${_formatDate(submittedAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (appeal['reviewedAt'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Reviewed: ${_formatDate(DateTime.parse(appeal['reviewedAt']))}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (appeal['reviewComments'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Review Comments: ${appeal['reviewComments']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showReviewDialog(context, appeal, 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showReviewDialog(context, appeal, 'rejected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, Map<String, dynamic> appeal, String status) {
    final TextEditingController commentsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${status == 'approved' ? 'Approve' : 'Reject'} Appeal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${appeal['username']}'),
            Text('Ban Type: ${appeal['banType'].toUpperCase()}'),
            const SizedBox(height: 16),
            Text('Appeal Reason: ${appeal['appealReason']}'),
            const SizedBox(height: 16),
            TextField(
              controller: commentsController,
              decoration: InputDecoration(
                labelText: status == 'approved' ? 'Approval comments (optional)' : 'Rejection reason',
                border: const OutlineInputBorder(),
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
              if (status == 'rejected' && commentsController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a rejection reason.')),
                );
                return;
              }
              
              Navigator.of(context).pop();
              onReview(appeal, status, commentsController.text.trim().isEmpty ? null : commentsController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'approved' ? Colors.green : Colors.red,
            ),
            child: Text(
              status == 'approved' ? 'Approve' : 'Reject',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
