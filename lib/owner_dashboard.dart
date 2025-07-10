import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'shared_widgets.dart';
import 'notifications_page.dart';
import 'profile_validator.dart';
import 'owner_customer_list.dart';
import 'owner_profile.dart' as owner;



class House {
  final String id;
  final String address;
  final String phone;
  final List<Map<String, dynamic>> prices;
  final DateTime availableFrom;
  final DateTime availableTo;
  final List<String> imageUrls;

  House({
    required this.id,
    required this.address,
    required this.phone,
    required this.prices,
    required this.availableFrom,
    required this.availableTo,
    this.imageUrls = const [],
  });

  factory House.fromMap(String id, Map<String, dynamic> data) {
    return House(
      id: id,
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      prices: List<Map<String, dynamic>>.from(data['prices'] ?? []),
      availableFrom: DateTime.parse(data['availableFrom'] ?? DateTime.now().toIso8601String()),
      availableTo: DateTime.parse(data['availableTo'] ?? DateTime.now().toIso8601String()),
      imageUrls: data['imageUrls'] != null ? List<String>.from(data['imageUrls']) : [],
    );
  }

  Map<String, dynamic> toMap() => {
    'address': address,
    'phone': phone,
    'prices': prices,
    'availableFrom': availableFrom.toIso8601String(),
    'availableTo': availableTo.toIso8601String(),
    'imageUrls': imageUrls,
  };
}

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({Key? key}) : super(key: key);

  @override
  _OwnerHomePageState createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  int _currentIndex = 0;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('AppUsers')
        .where('email', isEqualTo: user.email)
        .limit(1)
        .get();
    
    if (usersSnapshot.docs.isNotEmpty && mounted) {
      setState(() {
        _username = usersSnapshot.docs.first.id;
      });
    }
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'StoraNova';
      case 1:
        return 'Customer Management';
      case 2:
        return 'Notifications';
      case 3:
        return _username != null ? '@$_username' : 'Profile';
      default:
        return 'StoraNova';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OwnerAppBar(title: _getPageTitle(_currentIndex)),
      endDrawer: const OwnerDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          OwnerDashboardContent(),
          OwnerCustomerListPage(isEmbedded: true),
          NotificationsPage(expectedRole: 'owner', isEmbedded: true),
          owner.ProfileScreen(isEmbedded: true),
        ],
      ),
      bottomNavigationBar: OwnerNavBar(
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

class OwnerDashboardContent extends StatefulWidget {
  @override
  _OwnerDashboardContentState createState() => _OwnerDashboardContentState();
}

class _OwnerDashboardContentState extends State<OwnerDashboardContent> {
  House? _house;
  bool _isLoading = true;
  bool _showHouseForm = false;
  final _houseFormKey = GlobalKey<FormState>();
  final TextEditingController _houseAddressController = TextEditingController();
  final TextEditingController _housePhoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  // New form fields for the updated requirements
  final TextEditingController _maxItemQuantityController = TextEditingController();
  final TextEditingController _pricePerItemController = TextEditingController();
  final TextEditingController _pickupServiceCostController = TextEditingController();
  
  // Payment methods - multiple selection allowed
  Map<String, bool> _paymentMethods = {
    'cash': false,
    'online_banking': false,
    'ewallet': false,
  };
  
  // Pickup service
  bool _offerPickupService = false;
  
  DateTime? _availableFrom;
  DateTime? _availableTo;
  final DatabaseService _db = DatabaseService();
  // Unified image list: String (url) for existing, Uint8List for new
  List<dynamic> _formImages = [];
  bool _isUploadingImages = false;
  final ImagePicker _picker = ImagePicker();
  
  // Proof of ownership
  dynamic _proofOfOwnership; // Can be Uint8List for new or String for existing URL
  String? _proofOfOwnershipType; // Track file type: 'image' or 'pdf'
  bool _isUploadingProof = false;
  
  // House applications data
  List<Map<String, dynamic>> _applications = [];
  bool _hasApprovedHouse = false;
  String? _editingApplicationId; // Track if we're editing an existing application

  // House status data
  bool _houseIsAvailable = true;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _checkUserBanStatus();
    _fetchHouseApplications();
  }

  Future<void> _checkUserBanStatus() async {
    try {
      final username = await _getUsernameFromFirestore();
      if (username != null) {
        final userDoc = await _db.getUserByUsername(username);
        if (userDoc != null && userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final isUserBanned = userData['isBanned'] == true;
          
          if (isUserBanned) {
            // Redirect to notifications page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationsPage(expectedRole: 'owner'),
              ),
            );
            return;
          }
        }
      }
    } catch (e) {
      print('Error checking ban status: $e');
    }
  }

  Future<String?> _getUsernameFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    // Try to get username from AppUsers by UID, then by email, then by displayName
    DocumentSnapshot? userDoc;
    if (user.uid.isNotEmpty) {
      userDoc = await FirebaseFirestore.instance.collection('AppUsers').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null && (userDoc.data() as Map<String, dynamic>)['username'] != null) {
        return (userDoc.data() as Map<String, dynamic>)['username'];
      }
    }
    if (user.email != null && user.email!.isNotEmpty) {
      final query = await FirebaseFirestore.instance.collection('AppUsers').where('email', isEqualTo: user.email).limit(1).get();
      if (query.docs.isNotEmpty && query.docs.first.data()['username'] != null) {
        return query.docs.first.data()['username'];
      }
    }
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      userDoc = await FirebaseFirestore.instance.collection('AppUsers').doc(user.displayName).get();
      if (userDoc.exists && userDoc.data() != null && (userDoc.data() as Map<String, dynamic>)['username'] != null) {
        return (userDoc.data() as Map<String, dynamic>)['username'];
      }
      return user.displayName;
    }
    return null;
  }

  void _showRegisterHouseForm({House? house}) async {
    // Check if profile is complete before allowing house registration
    final isProfileComplete = await ProfileValidator.isOwnerProfileComplete();
    if (!isProfileComplete) {
      ProfileValidator.showProfileIncompleteDialog(context, isOwner: true);
      return;
    }

    setState(() {
      _showHouseForm = true;
      _editingApplicationId = null; // Clear editing state for new application
      if (house != null) {
        _houseAddressController.text = house.address;
        _housePhoneController.text = house.phone;
        _availableFrom = house.availableFrom;
        _availableTo = house.availableTo;
        _formImages = List<dynamic>.from(house.imageUrls); // Always dynamic
        _proofOfOwnership = null; // Reset proof for editing
        _proofOfOwnershipType = null;
        
        // Reset new fields for editing - will be set from existing data if available
        _maxItemQuantityController.text = '';
        _pricePerItemController.text = '';
        _pickupServiceCostController.text = '';
        _paymentMethods = {'cash': false, 'online_banking': false, 'ewallet': false};
        _offerPickupService = false;
      } else {
        _houseAddressController.text = '';
        _housePhoneController.text = '';
        _descriptionController.text = '';
        _availableFrom = null;
        _availableTo = null;
        _formImages = [];
        _proofOfOwnership = null;
        _proofOfOwnershipType = null;
        
        // Reset new fields
        _maxItemQuantityController.text = '';
        _pricePerItemController.text = '';
        _pickupServiceCostController.text = '';
        _paymentMethods = {'cash': false, 'online_banking': false, 'ewallet': false};
        _offerPickupService = false;
      }
    });
  }

  Future<void> _autofillAddressFromProfile() async {
    final username = await _getUsernameFromFirestore();
    if (username == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('AppUsers').doc(username).get();
    final profile = userDoc.data();
    setState(() {
      _houseAddressController.text = profile?['address'] ?? '';
    });
  }

  Future<void> _autofillPhoneFromProfile() async {
    final username = await _getUsernameFromFirestore();
    if (username == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('AppUsers').doc(username).get();
    final profile = userDoc.data();
    setState(() {
      _housePhoneController.text = profile?['phone'] ?? '';
    });
  }



  Future<void> _pickHouseImage() async {
    if (_formImages.length >= 3) return;
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    Uint8List bytes;
    if (kIsWeb) {
      bytes = await pickedFile.readAsBytes();
    } else {
      final file = File(pickedFile.path);
      final fileSize = await file.length();
      if (fileSize > 20 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each image must be below 20MB.')),
        );
        return;
      }
      bytes = await file.readAsBytes();
    }
    setState(() {
      _formImages.add(bytes);
    });
  }

  Future<String?> _uploadImageToCloudinary(Uint8List imageBytes) async {
    const String uploadPreset = 'StoraNova';
    const String cloudName = 'dxeejx1hq';
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'house_image.png'));
    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(respStr);
        return data['secure_url'];
      } else {
        print('Cloudinary upload failed: \\${response.statusCode}');
        print('Cloudinary error response: \\${respStr}');
        return null;
      }
    } catch (e) {
      print('Cloudinary upload exception: $e');
      return null;
    }
  }

  Future<List<String>> _uploadImagesToCloudinary(List<dynamic> images) async {
    List<String> urls = [];
    for (var img in images) {
      if (img is String) {
        urls.add(img); // Already uploaded
      } else if (img is Uint8List) {
        final url = await _uploadImageToCloudinary(img);
        if (url != null) {
          urls.add(url);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload one of the images. Please try again.')),
          );
          return [];
        }
      }
    }
    return urls;
  }

  Future<void> _submitHouse() async {
    if (!_houseFormKey.currentState!.validate() || _availableFrom == null || _availableTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields and select dates.')),
      );
      return;
    }
    
    // Validate that at least one payment method is selected
    bool hasPaymentMethod = _paymentMethods.values.any((selected) => selected);
    if (!hasPaymentMethod) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one payment method.')),
      );
      return;
    }
    
    final username = await _getUsernameFromFirestore();
    if (username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Please log in again.')),
      );
      return;
    }
    setState(() { _isLoading = true; _isUploadingImages = true; });
    try {
      final uploadedUrls = await _uploadImagesToCloudinary(_formImages);
      if (uploadedUrls.length != _formImages.length) {
        setState(() { _isLoading = false; _isUploadingImages = false; });
        return;
      }
      
      // Upload proof of ownership if provided
      String? proofUrl;
      if (_proofOfOwnership != null) {
        setState(() { _isUploadingProof = true; });
        if (_proofOfOwnership is Uint8List) {
          proofUrl = await _uploadImageToCloudinary(_proofOfOwnership);
          if (proofUrl == null) {
            setState(() { _isLoading = false; _isUploadingImages = false; _isUploadingProof = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload proof of ownership. Please try again.')),
            );
            return;
          }
        } else if (_proofOfOwnership is String) {
          proofUrl = _proofOfOwnership;
        }
        setState(() { _isUploadingProof = false; });
      }
      
      if (_editingApplicationId != null) {
        // Update existing application
        await _db.updateHouseApplication(
          applicationId: _editingApplicationId!,
          address: _houseAddressController.text.trim(),
          phone: _housePhoneController.text.trim(),
          prices: [], // Empty since we're using new pricing structure
          availableFrom: _availableFrom!,
          availableTo: _availableTo!,
          imageUrls: uploadedUrls,
          description: _descriptionController.text.trim(),
          proofOfOwnershipUrl: proofUrl,
          paymentMethods: _paymentMethods,
          maxItemQuantity: _maxItemQuantityController.text.trim(),
          pricePerItem: _pricePerItemController.text.trim(),
          offerPickupService: _offerPickupService,
          pickupServiceCost: _offerPickupService ? _pickupServiceCostController.text.trim() : null,
        );
      } else {
        // Check if owner already has an application
        final hasExisting = await _db.hasExistingApplication(username);
        if (hasExisting) {
          setState(() { _isLoading = false; _isUploadingImages = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You already have an application. Please edit your existing application instead.')),
          );
          return;
        }
        
        // Submit new application
        await _db.submitHouseApplication(
          ownerUsername: username,
          address: _houseAddressController.text.trim(),
          phone: _housePhoneController.text.trim(),
          prices: [], // Empty since we're using new pricing structure
          availableFrom: _availableFrom!,
          availableTo: _availableTo!,
          imageUrls: uploadedUrls,
          description: _descriptionController.text.trim(),
          proofOfOwnershipUrl: proofUrl,
          paymentMethods: _paymentMethods,
          maxItemQuantity: _maxItemQuantityController.text.trim(),
          pricePerItem: _pricePerItemController.text.trim(),
          offerPickupService: _offerPickupService,
          pickupServiceCost: _offerPickupService ? _pickupServiceCostController.text.trim() : null,
        );
      }
      setState(() { 
        _showHouseForm = false; 
        _formImages = []; 
        _proofOfOwnership = null;
        _proofOfOwnershipType = null;
        _editingApplicationId = null; // Clear editing state
        
        // Reset new form fields
        _maxItemQuantityController.clear();
        _pricePerItemController.clear();
        _pickupServiceCostController.clear();
        _paymentMethods = {'cash': false, 'online_banking': false, 'ewallet': false};
        _offerPickupService = false;
      });
      await _fetchHouseApplications();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editingApplicationId != null 
          ? 'Application updated successfully! Please wait for admin review.' 
          : 'House application submitted successfully! Please wait for admin approval.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: [${e.toString()}')),
      );
    } finally {
      setState(() { 
        _isLoading = false; 
        _isUploadingImages = false; 
        _isUploadingProof = false;
      });
    }
  }

  Future<void> _fetchHouseApplications() async {
    setState(() { _isLoading = true; });
    final username = await _getUsernameFromFirestore();
    if (username == null) {
      setState(() { _isLoading = false; });
      return;
    }
    
    try {
      // Fetch applications for this owner
      final applications = await _db.getHouseApplicationsByOwner(username);
      
      // Check if owner has approved house
      final hasApproved = await _db.hasApprovedHouse(username);
      
      setState(() {
        _applications = applications;
        _hasApprovedHouse = hasApproved;
        _isLoading = false;
      });
      
      // Fetch house status if approved
      if (hasApproved) {
        await _fetchHouseStatus();
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching applications: $e')),
      );
    }
  }

  Future<void> _fetchHouseStatus() async {
    if (!_hasApprovedHouse) return;
    
    final username = await _getUsernameFromFirestore();
    if (username == null) return;
    
    try {
      final status = await _db.getHouseStatus(username);
      setState(() {
        _houseIsAvailable = status;
      });
    } catch (e) {
      // Handle error silently or show message
    }
  }

  Future<void> _toggleHouseStatus() async {
    final username = await _getUsernameFromFirestore();
    if (username == null) return;
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    try {
      await _db.updateHouseStatus(
        ownerUsername: username,
        isAvailable: !_houseIsAvailable,
      );
      
      setState(() {
        _houseIsAvailable = !_houseIsAvailable;
        _isUpdatingStatus = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_houseIsAvailable 
            ? 'Your house is now available for bookings'
            : 'Your house is now hidden from customers'),
        ),
      );
    } catch (e) {
      setState(() {
        _isUpdatingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  @override
  void dispose() {
    _houseAddressController.dispose();
    _housePhoneController.dispose();
    _descriptionController.dispose();
    _maxItemQuantityController.dispose();
    _pricePerItemController.dispose();
    _pickupServiceCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text(
                  'We are processing your house registration...\nHang tight, this may take a few moments!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    if (!_hasApprovedHouse && _applications.isEmpty && !_showHouseForm)
                      Column(
                        children: [
                          const SizedBox(height: 40),
                          Center(
                            child: Text(
                              'Welcome! Submit your house application for admin approval.\nOnce approved, you can start earning!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () => _showRegisterHouseForm(),
                              icon: const Icon(Icons.add_home),
                              label: const Text('Submit House Application'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    if (_applications.isNotEmpty && !_showHouseForm) 
                      _buildApplicationsList(),
                    if (_showHouseForm) _buildHouseForm(),
                    if (_house != null && !_showHouseForm) ...[
                      const Text('Your House:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Card(
                        color: Colors.white,
                        child: Column(
                          children: [
                            if (_house!.imageUrls.isNotEmpty)
                              Column(
                                children: [
                                  SizedBox(
                                    height: 200,
                                    child: _HouseImageSlider(imageUrls: _house!.imageUrls),
                                  ),
                                ],
                              ),
                            ListTile(
                              title: Text(_house!.address),
                              subtitle: Text('Phone: ${_house!.phone}\nPrices: ${_house!.prices.map((p) => '${p['amount']} ${p['unit']}').join(', ')}\nAvailable: ${_house!.availableFrom.toLocal().toString().split(' ')[0]} to ${_house!.availableTo.toLocal().toString().split(' ')[0]}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showRegisterHouseForm(house: _house),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete House'),
                                          content: const Text('Are you sure you want to delete your house registration?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        final username = await _getUsernameFromFirestore();
                                        if (username != null) {
                                          await FirebaseFirestore.instance.collection('Houses').doc(username).delete();
                                          setState(() { _house = null; });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('House registration deleted.')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
  }

  Widget _buildHouseForm() {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _houseFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Register/Edit House Application', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              // Unified image preview and delete for both uploaded and new images
              Row(
                children: [
                  ..._formImages.asMap().entries.map((entry) {
                    int i = entry.key;
                    var img = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          GestureDetector(
                            onTap: null,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[200],
                              ),
                              child: img is String
                                ? Image.network(img, fit: BoxFit.cover)
                                : Image.memory(img, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red, size: 20),
                              onPressed: _isUploadingImages ? null : () {
                                setState(() {
                                  _formImages.removeAt(i);
                                });
                              },
                            ),
                          ),
                          if (_isUploadingImages && img is Uint8List)
                            const Positioned.fill(
                              child: Center(
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(strokeWidth: 3),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (_formImages.length < 3)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: GestureDetector(
                        onTap: _isUploadingImages ? null : _pickHouseImage,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200],
                          ),
                          child: const Icon(Icons.add_a_photo, size: 32, color: Colors.blue),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _houseAddressController,
                      decoration: const InputDecoration(labelText: 'House Address'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async { await _autofillAddressFromProfile(); },
                    child: const Text('Same as Profile'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _housePhoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async { await _autofillPhoneFromProfile(); },
                    child: const Text('Same as Profile'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Payment methods section
              const Text('Payment Methods:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select payment methods you accept (can select multiple):', 
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Cash'),
                      value: _paymentMethods['cash'],
                      onChanged: (value) {
                        setState(() {
                          _paymentMethods['cash'] = value ?? false;
                        });
                      },
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: const Text('Online Banking'),
                      value: _paymentMethods['online_banking'],
                      onChanged: (value) {
                        setState(() {
                          _paymentMethods['online_banking'] = value ?? false;
                        });
                      },
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: const Text('E-Wallet'),
                      value: _paymentMethods['ewallet'],
                      onChanged: (value) {
                        setState(() {
                          _paymentMethods['ewallet'] = value ?? false;
                        });
                      },
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Max item quantity and price per item
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxItemQuantityController,
                      decoration: const InputDecoration(labelText: 'Max Items Quantity'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _pricePerItemController,
                      decoration: const InputDecoration(labelText: 'Price per Item (RM)'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Pickup service section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: const Text('Offer Pickup Service'),
                      subtitle: const Text('Check this if you want to offer pickup service to customers'),
                      value: _offerPickupService,
                      onChanged: (value) {
                        setState(() {
                          _offerPickupService = value ?? false;
                          if (!_offerPickupService) {
                            _pickupServiceCostController.clear();
                          }
                        });
                      },
                      dense: true,
                    ),
                    if (_offerPickupService) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _pickupServiceCostController,
                        decoration: const InputDecoration(labelText: 'Pickup Service Cost (RM)'),
                        keyboardType: TextInputType.number,
                        validator: (v) => _offerPickupService && (v == null || v.isEmpty) ? 'Required when offering pickup service' : null,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Duration Available For Booking:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(_availableFrom == null ? 'From: Not set' : 'From: ${_availableFrom!.toLocal().toString().split(' ')[0]}'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() { _availableFrom = picked; });
                    },
                    child: const Text('Pick Start'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(_availableTo == null ? 'To: Not set' : 'To: ${_availableTo!.toLocal().toString().split(' ')[0]}'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _availableFrom ?? DateTime.now(),
                        firstDate: _availableFrom ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() { _availableTo = picked; });
                    },
                    child: const Text('Pick End'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Describe your property, amenities, location benefits, etc.',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              
              // Proof of Ownership Section
              const Text('Proof of House Ownership (Required):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please upload a document that proves your ownership of the house (e.g., property deed, ownership certificate, etc.)',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (_proofOfOwnership == null) ...[
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingProof ? null : _pickProofOfOwnership,
                          icon: _isUploadingProof 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file),
                          label: Text(_isUploadingProof ? 'Uploading...' : 'Upload Proof of Ownership (Image/PDF)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.description, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Proof of ownership uploaded (${_proofOfOwnershipType ?? 'file'})')),
                          IconButton(
                            onPressed: _isUploadingProof ? null : () {
                              setState(() {
                                _proofOfOwnership = null;
                                _proofOfOwnershipType = null;
                              });
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _submitHouse,
                    child: Text(_editingApplicationId != null ? 'Update Application' : 'Submit Application'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () { setState(() { _showHouseForm = false; }); },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'House Applications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _applications.length,
          itemBuilder: (context, index) {
            final application = _applications[index];
            return _buildApplicationCard(application);
          },
        ),
      ],
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final status = application['status'] as String;
    final submittedAt = DateTime.parse(application['submittedAt']);
    
    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with address and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    application['address'] ?? 'No address',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Application details
            _buildDetailRow('Phone', application['phone'] ?? 'N/A'),
            _buildDetailRow('Submitted', _formatDate(submittedAt)),
            
            if (application['description'] != null && application['description'].isNotEmpty)
              _buildDetailRow('Description', application['description']),
            
            // Pricing information
            if (application['prices'] != null && (application['prices'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Pricing:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(application['prices'] as List).map((price) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text('• RM${price['amount']} ${price['unit']}'),
              )),
            ],
            
            // Availability
            if (application['availableFrom'] != null && application['availableTo'] != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Available From', _formatDate(DateTime.parse(application['availableFrom']))),
              _buildDetailRow('Available To', _formatDate(DateTime.parse(application['availableTo']))),
            ],
            
            // Review information
            if (application['reviewedAt'] != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow('Reviewed', _formatDate(DateTime.parse(application['reviewedAt']))),
              _buildDetailRow('Reviewed By', application['reviewedBy'] ?? 'N/A'),
              if (application['reviewComments'] != null && application['reviewComments'].isNotEmpty)
                _buildDetailRow('Admin Comments', application['reviewComments'], isComment: true),
            ],
            
            const SizedBox(height: 16),
            
            // Status messages and actions
            if (status == 'pending') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Your application is being reviewed by the admin. You can edit it while it\'s pending.',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editApplication(application),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Application'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showApplicationDetails(application),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Congratulations! Your house has been approved and is now available for customers.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // House Status Toggle
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _houseIsAvailable ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _houseIsAvailable ? Colors.blue.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _houseIsAvailable ? Icons.visibility : Icons.visibility_off,
                      color: _houseIsAvailable ? Colors.blue : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _houseIsAvailable 
                          ? 'Your house is visible to customers and accepting bookings'
                          : 'Your house is hidden from customers (not accepting bookings)',
                        style: TextStyle(
                          color: _houseIsAvailable ? Colors.blue : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_isUpdatingStatus)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Switch(
                        value: _houseIsAvailable,
                        onChanged: (value) => _toggleHouseStatus(),
                        activeColor: Colors.green,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editApprovedHouse(application),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit (Requires Re-approval)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showApplicationDetails(application),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'rejected') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Your application was rejected. Please review the admin comments and submit a new application.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editApplication(application),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Resubmit Application'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showApplicationDetails(application),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
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

  Widget _buildDetailRow(String label, String value, {bool isComment = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontStyle: isComment ? FontStyle.italic : FontStyle.normal,
                color: isComment ? Colors.grey[600] : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _editApplication(Map<String, dynamic> application) {
    // Set editing state - now using owner username as ID
    _editingApplicationId = application['ownerUsername'];
    
    // Pre-fill the form with existing application data
    _houseAddressController.text = application['address'] ?? '';
    _housePhoneController.text = application['phone'] ?? '';
    _descriptionController.text = application['description'] ?? '';
    
    // Parse prices (keeping for backward compatibility but not using in form)
    // Legacy prices are no longer editable, using new pricing structure instead
    
    // Parse new fields
    _maxItemQuantityController.text = application['maxItemQuantity']?.toString() ?? '';
    _pricePerItemController.text = application['pricePerItem']?.toString() ?? '';
    _pickupServiceCostController.text = application['pickupServiceCost']?.toString() ?? '';
    
    // Parse payment methods
    if (application['paymentMethods'] != null) {
      final Map<String, dynamic> savedMethods = Map<String, dynamic>.from(application['paymentMethods']);
      _paymentMethods = {
        'cash': savedMethods['cash'] == true,
        'online_banking': savedMethods['online_banking'] == true,
        'ewallet': savedMethods['ewallet'] == true,
      };
    } else {
      _paymentMethods = {'cash': false, 'online_banking': false, 'ewallet': false};
    }
    
    // Parse pickup service
    _offerPickupService = application['offerPickupService'] == true;
    
    // Parse dates
    if (application['availableFrom'] != null) {
      _availableFrom = DateTime.parse(application['availableFrom']);
    }
    if (application['availableTo'] != null) {
      _availableTo = DateTime.parse(application['availableTo']);
    }
    
    // Parse images
    if (application['imageUrls'] != null) {
      _formImages = List<dynamic>.from(application['imageUrls']);
    } else {
      _formImages = [];
    }
    
    // Parse proof of ownership
    if (application['proofOfOwnershipUrl'] != null) {
      _proofOfOwnership = application['proofOfOwnershipUrl'];
      final url = application['proofOfOwnershipUrl'] as String;
      _proofOfOwnershipType = url.toLowerCase().contains('.pdf') ? 'pdf' : 'image';
    } else {
      _proofOfOwnership = null;
      _proofOfOwnershipType = null;
    }
    
    setState(() {
      _showHouseForm = true;
    });
  }

  void _editApprovedHouse(Map<String, dynamic> application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Approved House'),
        content: const Text(
          'Editing an approved house will require re-approval from the admin. '
          'Your house will be temporarily unavailable to customers until the admin reviews your changes.\n\n'
          'Do you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _editApplication(application);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showApplicationDetails(Map<String, dynamic> application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Application Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Address', application['address'] ?? 'N/A'),
              _buildDetailRow('Phone', application['phone'] ?? 'N/A'),
              _buildDetailRow('Status', application['status'] ?? 'N/A'),
              _buildDetailRow('Submitted', _formatDate(DateTime.parse(application['submittedAt']))),
              
              if (application['description'] != null && application['description'].isNotEmpty)
                _buildDetailRow('Description', application['description']),
              
              if (application['availableFrom'] != null && application['availableTo'] != null) ...[
                _buildDetailRow('Available From', _formatDate(DateTime.parse(application['availableFrom']))),
                _buildDetailRow('Available To', _formatDate(DateTime.parse(application['availableTo']))),
              ],
              
              if (application['reviewedAt'] != null) ...[
                const SizedBox(height: 16),
                const Text('Review Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDetailRow('Reviewed At', _formatDate(DateTime.parse(application['reviewedAt']))),
                _buildDetailRow('Reviewed By', application['reviewedBy'] ?? 'N/A'),
              ],
              
              if (application['reviewComments'] != null && application['reviewComments'].isNotEmpty)
                _buildDetailRow('Admin Comments', application['reviewComments'], isComment: true),
              
              // Prices
              if (application['prices'] != null && (application['prices'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Pricing:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...(application['prices'] as List).map((price) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• RM${price['amount']} ${price['unit']}'),
                )),
              ],
              
              // Images
              if (application['imageUrls'] != null && (application['imageUrls'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Images:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (application['imageUrls'] as List).map<Widget>((imageUrl) {
                    return GestureDetector(
                      onTap: () => _showFullScreenImage(imageUrl),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
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
    );
  }

  Future<void> _pickProofOfOwnership() async {
    try {
      // Show dialog to choose between image and PDF
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Proof of Ownership'),
          content: const Text('Choose the type of file you want to upload:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('image'),
              child: const Text('Image'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('pdf'),
              child: const Text('PDF'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (result == null) return;

      Uint8List? bytes;
      
      if (result == 'image') {
        final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile == null) return;
        
        if (kIsWeb) {
          bytes = await pickedFile.readAsBytes();
        } else {
          final file = File(pickedFile.path);
          final fileSize = await file.length();
          if (fileSize > 20 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Proof of ownership file must be below 20MB.')),
            );
            return;
          }
          bytes = await file.readAsBytes();
        }
        setState(() {
          _proofOfOwnership = bytes;
          _proofOfOwnershipType = 'image';
        });
      } else if (result == 'pdf') {
        final pickedFile = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );
        
        if (pickedFile == null || pickedFile.files.isEmpty) return;
        
        final file = pickedFile.files.first;
        
        if (file.size > 20 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Proof of ownership file must be below 20MB.')),
          );
          return;
        }
        
        if (kIsWeb && file.bytes != null) {
          bytes = file.bytes!;
        } else if (!kIsWeb && file.path != null) {
          final fileObj = File(file.path!);
          bytes = await fileObj.readAsBytes();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to read the selected file.')),
          );
          return;
        }
        
        setState(() {
          _proofOfOwnership = bytes;
          _proofOfOwnershipType = 'pdf';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }
}

// --- Image slider with dot indicator ---
class _HouseImageSlider extends StatefulWidget {
  final List<String> imageUrls;
  const _HouseImageSlider({Key? key, required this.imageUrls}) : super(key: key);

  @override
  State<_HouseImageSlider> createState() => _HouseImageSliderState();
}

class _HouseImageSliderState extends State<_HouseImageSlider> {
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

  void _showFullScreenImage(String url) {
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
                  icon: const Icon(Icons.close, color: Colors.black, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToPage(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView(
          controller: _controller,
          onPageChanged: (i) => setState(() => _currentPage = i),
          children: widget.imageUrls.map((url) => GestureDetector(
            onTap: () => _showFullScreenImage(url),
            child: Image.network(url, fit: BoxFit.cover),
          )).toList(),
        ),
        if (widget.imageUrls.length > 1)
          Positioned(
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left arrow
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  color: _currentPage > 0 ? Colors.blue : Colors.grey,
                  onPressed: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
                ...List.generate(widget.imageUrls.length, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == i ? Colors.blue : Colors.grey,
                  ),
                )),
                // Right arrow
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  color: _currentPage < widget.imageUrls.length - 1 ? Colors.blue : Colors.grey,
                  onPressed: _currentPage < widget.imageUrls.length - 1 ? () => _goToPage(_currentPage + 1) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}