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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdminAppBar(title: 'Admin Dashboard'),
      endDrawer: const AdminDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HouseApplicationsPage(),
          UserManagementPage(),
          AppealsManagementPage(),
          AdminProfilePage(),
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

class UserManagementPage extends StatefulWidget {
  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final DatabaseService _dbService = DatabaseService();
  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> users;
      if (_selectedFilter == 'all') {
        users = await _dbService.getAllUsers();
      } else {
        users = await _dbService.getAllUsers(role: _selectedFilter);
      }
      
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e')),
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
              const Text('Filter by Role: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                    _loadUsers();
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
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'No ${_selectedFilter == 'all' ? '' : _selectedFilter} users found',
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return UserCard(
                            user: user,
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating house status: $e')),
      );
    }
  }
}

class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Function(String, String, bool, String?) onBanUser;
  final Function(String, String, bool, String?) onBanHouse;

  const UserCard({
    Key? key,
    required this.user,
    required this.onBanUser,
    required this.onBanHouse,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String;
    final isBanned = user['isBanned'] ?? false;
    final isOwner = role == 'owner';
    
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'No name',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text('Username: ${user['username'] ?? user['id']}'),
                      Text('Email: ${user['email'] ?? 'N/A'}'),
                      Text('Role: ${role.toUpperCase()}'),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _StatusChip(
                      status: isBanned ? 'banned' : 'active',
                      color: isBanned ? Colors.red : Colors.green,
                    ),
                    if (isOwner && user['isHouseBanned'] == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: _StatusChip(
                          status: 'house banned',
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            if (user['banReason'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ban Reason: ${user['banReason']}',
                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.red),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
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
                    ),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showBanDialog(context, true),
                      icon: Icon(
                        (user['isHouseBanned'] ?? false) ? Icons.home : Icons.home_outlined,
                        color: Colors.white,
                      ),
                      label: Text(
                        (user['isHouseBanned'] ?? false) ? 'Unban House' : 'Ban House',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (user['isHouseBanned'] ?? false) ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBanDialog(BuildContext context, bool isHouseBan) {
    final TextEditingController reasonController = TextEditingController();
    final isCurrentlyBanned = isHouseBan ? (user['isHouseBanned'] ?? false) : (user['isBanned'] ?? false);
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
              
              Navigator.of(context).pop();
              
              if (isHouseBan) {
                onBanHouse(
                  user['username'] ?? user['id'],
                  user['name'] ?? 'Unknown',
                  !isCurrentlyBanned,
                  reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                );
              } else {
                onBanUser(
                  user['username'] ?? user['id'],
                  user['name'] ?? 'Unknown',
                  !isCurrentlyBanned,
                  reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                );
              }
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
                  '${appeal['username']} - ${banType.toUpperCase()} Ban Appeal',
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
