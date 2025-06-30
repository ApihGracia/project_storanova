import 'package:flutter/material.dart';
import 'owner_profile.dart';
import 'main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(OwnerDashboard());
}

class OwnerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: OwnerHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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
  int _currentIndex = 2;
  House? _house;
  bool _isLoading = true;
  bool _showHouseForm = false;
  final _houseFormKey = GlobalKey<FormState>();
  final TextEditingController _houseAddressController = TextEditingController();
  final TextEditingController _housePhoneController = TextEditingController();
  List<Map<String, dynamic>> _prices = [];
  String _priceUnit = 'per day';
  DateTime? _availableFrom;
  DateTime? _availableTo;
  final DatabaseService _db = DatabaseService();
  // Unified image list: String (url) for existing, Uint8List for new
  List<dynamic> _formImages = [];
  bool _isUploadingImages = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchHouse();
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

  Future<void> _fetchHouse() async {
    setState(() { _isLoading = true; });
    final username = await _getUsernameFromFirestore();
    if (username == null) {
      setState(() { _isLoading = false; });
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('Houses').doc(username).get();
    setState(() {
      _house = doc.exists ? House.fromMap(doc.id, doc.data()!) : null;
      _isLoading = false;
    });
  }

  void _showRegisterHouseForm({House? house}) {
    setState(() {
      _showHouseForm = true;
      if (house != null) {
        _houseAddressController.text = house.address;
        _housePhoneController.text = house.phone;
        _prices = List<Map<String, dynamic>>.from(house.prices);
        _priceUnit = house.prices.isNotEmpty ? house.prices[0]['unit'] : 'per day';
        _availableFrom = house.availableFrom;
        _availableTo = house.availableTo;
        _formImages = List<dynamic>.from(house.imageUrls); // Always dynamic
      } else {
        _houseAddressController.text = '';
        _housePhoneController.text = '';
        _prices = [];
        _priceUnit = 'per day';
        _availableFrom = null;
        _availableTo = null;
        _formImages = [];
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

  void _addPriceField() {
    setState(() {
      _prices.add({'amount': '', 'unit': _priceUnit});
    });
  }

  Future<void> _pickHouseImage() async {
    if (_formImages.length >= 3) return;
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final file = File(pickedFile.path);
    final fileSize = await file.length();
    if (fileSize > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Each image must be below 20MB.')),
      );
      return;
    }
    final bytes = await file.readAsBytes();
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
      await _db.createHouse(
        username: username,
        address: _houseAddressController.text.trim(),
        phone: _housePhoneController.text.trim(),
        prices: _prices,
        availableFrom: _availableFrom!,
        availableTo: _availableTo!,
        imageUrls: uploadedUrls,
      );
      setState(() { _showHouseForm = false; _formImages = []; });
      await _fetchHouse();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('House registered/updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: [${e.toString()}')),
      );
    } finally {
      setState(() { _isLoading = false; _isUploadingImages = false; });
    }
  }

  @override
  void dispose() {
    _houseAddressController.dispose();
    _housePhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              'StoraNova(owner)',
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_house == null && !_showHouseForm)
                      Center(
                        child: ElevatedButton(
                          onPressed: () => _showRegisterHouseForm(),
                          child: const Text('Register New House'),
                        ),
                      ),
                    if (_showHouseForm) _buildHouseForm(),
                    if (_house != null && !_showHouseForm) ...[
                      const Text('Your House:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Card(
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
                              trailing: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showRegisterHouseForm(house: _house),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'Latest News',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 150,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildNewsCard(
                            imageUrl:
                                'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                          ),
                          _buildNewsCard(
                            imageUrl:
                                'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                          ),
                          _buildNewsCard(
                            imageUrl:
                                'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: StoraNovaNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
          if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
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

  Widget _buildHouseForm() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _houseFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Register/Edit House', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              ..._prices.asMap().entries.map((entry) {
                int idx = entry.key;
                return Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: entry.value['amount'],
                        decoration: const InputDecoration(labelText: 'Price'),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _prices[idx]['amount'] = val,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: entry.value['unit'],
                      items: const [
                        DropdownMenuItem(value: 'per day', child: Text('per day')),
                        DropdownMenuItem(value: 'per week', child: Text('per week')),
                      ],
                      onChanged: (val) {
                        setState(() { _prices[idx]['unit'] = val ?? 'per day'; });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() { _prices.removeAt(idx); });
                      },
                    ),
                  ],
                );
              }),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _addPriceField,
                child: const Text('Add Price Option'),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _submitHouse,
                    child: const Text('Submit'),
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
              children: List.generate(widget.imageUrls.length, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == i ? Colors.blue : Colors.grey,
                ),
              )),
            ),
          ),
      ],
    );
  }
}