import 'package:flutter/material.dart';
import 'main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'owner_dashboard.dart'; // For Flutter web image picking
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class ProfileData {
  ProfileData({
    required this.legalName,
    required this.role,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.emergencyContact,
  });

  final String legalName;
  final String role;
  final String phoneNumber;
  final String email;
  final String address;
  final String emergencyContact;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profile App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFADD8E6),
      ),
      home: const ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isEditing = false;
  String? _originalName;
  String? _originalPhone;
  String? _originalEmail;
  String? _originalAddress;
  String? imageUrl;
  String? name;
  String? role;
  String? phone;
  String? email;
  String? address;
  String? username;
  bool isLoading = true;
  int _currentIndex = 3; // 0: Home, 1: Wishlist, 2: Notification, 3: Profile
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageUrlPreview;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { isLoading = false; });
      return;
    }
    String? resolvedUsername = user.displayName;
    if (resolvedUsername == null || resolvedUsername.isEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (userDoc.docs.isNotEmpty) {
        resolvedUsername = userDoc.docs.first.id;
      } else {
        setState(() { isLoading = false; });
        return;
      }
    }
    final doc = await FirebaseFirestore.instance.collection('AppUsers').doc(resolvedUsername).get();
    final data = doc.data();
    setState(() {
      username = resolvedUsername;
      imageUrl = (data?['profileImageUrl'] ?? '') as String;
      name = (data?['name'] ?? '') as String;
      role = (data?['role'] ?? '') as String;
      phone = (data?['phone'] ?? '') as String;
      email = (data?['email'] ?? user.email ?? '') as String;
      address = (data?['address'] ?? '') as String;
      _nameController.text = name ?? '';
      _phoneController.text = phone ?? '';
      _emailController.text = email ?? '';
      _addressController.text = address ?? '';
      isLoading = false;
      _originalName = name ?? '';
      _originalPhone = phone ?? '';
      _originalEmail = email ?? '';
      _originalAddress = address ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      isEditing = false;
      _nameController.text = _originalName ?? '';
      _phoneController.text = _originalPhone ?? '';
      _emailController.text = _originalEmail ?? '';
      _addressController.text = _originalAddress ?? '';
      _selectedImageBytes = null;
      _selectedImageUrlPreview = null;
    });
  }

  // Image picking and confirmation logic for Flutter web and mobile (cross-platform)
  Future<void> _pickImage() async {
    setState(() { _isUploadingImage = true; });
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      setState(() { _isUploadingImage = false; });
      return;
    }
    if (kIsWeb) {
      try {
        final imageBytes = await pickedFile.readAsBytes();
        // Show confirmation dialog with preview
        bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Image'),
            content: Image.memory(imageBytes, width: 200, height: 200),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Use Image')),
            ],
          ),
        );
        if (confirmed == true) {
          setState(() {
            _selectedImageBytes = imageBytes;
            _isUploadingImage = false;
          });
        } else {
          setState(() {
            _selectedImageBytes = null;
            _isUploadingImage = false;
          });
        }
      } catch (e) {
        setState(() { _isUploadingImage = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing image: $e')),
        );
      }
    } else {
      try {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        if (fileSize > 20 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image must be below 20MB.')),
          );
          setState(() { _isUploadingImage = false; });
          return;
        }
        // Show confirmation dialog with preview
        bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Image'),
            content: Image.file(file, width: 200, height: 200),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Use Image')),
            ],
          ),
        );
        if (confirmed == true) {
          final bytes = await file.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _isUploadingImage = false;
          });
        } else {
          setState(() {
            _selectedImageBytes = null;
            _isUploadingImage = false;
          });
        }
      } catch (e) {
        setState(() { _isUploadingImage = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImageToCloudinary(Uint8List imageBytes) async {
    const String uploadPreset = 'StoraNova';
    const String cloudName = 'dxeejx1hq';
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'profile_image.png'));
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { isLoading = true; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { isLoading = false; });
      return;
    }
    final newName = _nameController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newEmail = _emailController.text.trim();
    final newAddress = _addressController.text.trim();
    String? resolvedUsername = user.displayName;
    if (resolvedUsername == null || resolvedUsername.isEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (userDoc.docs.isNotEmpty) {
        resolvedUsername = userDoc.docs.first.id;
      } else {
        setState(() { isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine your username.')),
        );
        return;
      }
    }
    try {
      String? uploadedImageUrl = imageUrl;
      if (_selectedImageBytes != null) {
        setState(() { _isUploadingImage = true; });
        final url = await _uploadImageToCloudinary(_selectedImageBytes!);
        if (url != null) {
          uploadedImageUrl = url;
        } else {
          setState(() { isLoading = false; _isUploadingImage = false; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload failed. Please try again.')));
          return;
        }
        setState(() { _isUploadingImage = false; });
      }
      await FirebaseFirestore.instance.collection('AppUsers').doc(resolvedUsername).update({
        'name': newName,
        'phone': newPhone,
        'email': newEmail,
        'address': newAddress,
        'profileImageUrl': uploadedImageUrl ?? '',
      });
      // Wait a moment to ensure Firestore is updated before reloading
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        imageUrl = uploadedImageUrl;
        isEditing = false;
        _selectedImageBytes = null;
        _selectedImageUrlPreview = null;
      });
      await _loadProfile();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      setState(() { isLoading = false; _isUploadingImage = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      return;
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFB4D4FF),
        elevation: 0,
        title: Text(username != null && username!.isNotEmpty ? username! : 'Profile'),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
    // ...existing code...
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.blue,
                                width: 5,
                              ),
                            ),
                            child: ClipOval(
                              child: _selectedImageBytes != null
                                  ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                                  : (imageUrl == null || imageUrl!.isEmpty)
                                      ? Image.network(
                                          'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                                          fit: BoxFit.cover,
                                        )
                                      : Image.network(imageUrl!, fit: BoxFit.cover),
                            ),
                          ),
                          if (isEditing)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: InkWell(
                                onTap: _isUploadingImage ? null : _pickImage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: _isUploadingImage
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.camera_alt, color: Colors.blue),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_selectedImageBytes != null && isEditing)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('Preview. Click Save to upload.', style: TextStyle(color: Colors.blue)),
                      ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            enabled: isEditing,
                            style: const TextStyle(color: Colors.black),
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Name required' : null,
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: isEditing
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Contact admin to change your role.')),
                                    );
                                  }
                                : null,
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: TextEditingController(text: role ?? ''),
                                enabled: false,
                                style: const TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  labelText: 'Role',
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: isEditing ? Colors.grey[200] : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            enabled: isEditing,
                            style: const TextStyle(color: Colors.black),
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            enabled: isEditing,
                            style: const TextStyle(color: Colors.black),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Email required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            enabled: isEditing,
                            style: const TextStyle(color: Colors.black),
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isEditing)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                  child: SizedBox(
                                    width: 120,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFB4D4FF), // Match app bar color
                                        foregroundColor: Colors.black, // Black text for contrast
                                      ),
                                      onPressed: isLoading ? null : _startEdit,
                                      child: const Text('Edit'),
                                    ),
                                  ),
                                ),
                              if (isEditing) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                  child: SizedBox(
                                    width: 100,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFB4D4FF), // Match app bar color
                                        foregroundColor: Colors.black, // Black text for contrast
                                      ),
                                      onPressed: isLoading || _isUploadingImage ? null : _saveProfile,
                                      child: const Text('Save'),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                  child: SizedBox(
                                    width: 100,
                                    child: OutlinedButton(
                                      onPressed: isLoading || _isUploadingImage ? null : _cancelEdit,
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
          if (index < 0 || index > 3) return; // Safety: only allow 0-3
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
          if (index == 0) {
            // Home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OwnerHomePage()),
            );
          } else if (index == 1) {
            // Wishlist (implement if needed)
            // Navigator.pushReplacement(...)
          } else if (index == 2) {
            // Notification (implement if needed)
            // Navigator.pushReplacement(...)
          } else if (index == 3) {
            // Profile
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
      ),
    );
  }
  Widget _profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(value.isNotEmpty ? value : '', style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class ProfileRow extends StatelessWidget {
  const ProfileRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }
}