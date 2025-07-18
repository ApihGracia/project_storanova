import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'shared_widgets.dart';

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
        scaffoldBackgroundColor: const Color(0xFFE3F2FD), // Soft blue background to match main theme
      ),
      home: const ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final bool isEmbedded; // Whether this is embedded in another Scaffold
  
  const ProfileScreen({super.key, this.isEmbedded = false});

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
  // ...existing code...
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  Uint8List? _selectedImageBytes;
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
    final content = isLoading
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
                    const SizedBox(height: 50),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Single card containing all profile fields
                          Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Label section
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          'Name',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ':',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Value section
                                      Expanded(
                                        child: isEditing
                                            ? TextFormField(
                                                controller: _nameController,
                                                style: const TextStyle(color: Colors.black, fontSize: 16),
                                                decoration: const InputDecoration(
                                                  hintText: 'Enter your name',
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                                validator: (v) => v == null || v.isEmpty ? 'Name required' : null,
                                              )
                                            : Text(
                                                name ?? 'Not set',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: name != null && name!.isNotEmpty ? Colors.black : Colors.grey[500],
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Divider
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Divider(height: 1, color: Colors.grey),
                                  ),
                                  
                                  // Role Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Label section
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          'Role',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ':',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Value section
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: isEditing
                                              ? () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Contact admin to change your role.')),
                                                  );
                                                }
                                              : null,
                                          child: Row(
                                            children: [
                                              Text(
                                                role ?? 'Not set',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: role != null && role!.isNotEmpty ? Colors.black : Colors.grey[500],
                                                ),
                                              ),
                                              if (isEditing) ...[
                                                const SizedBox(width: 8),
                                                Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Divider
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Divider(height: 1, color: Colors.grey),
                                  ),
                                  
                                  // Phone Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Label section
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          'Phone',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ':',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Value section
                                      Expanded(
                                        child: isEditing
                                            ? TextFormField(
                                                controller: _phoneController,
                                                style: const TextStyle(color: Colors.black, fontSize: 16),
                                                decoration: const InputDecoration(
                                                  hintText: 'Enter your phone number',
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                                keyboardType: TextInputType.phone,
                                                validator: (v) => v == null || v.isEmpty ? 'Phone number required' : null,
                                              )
                                            : Text(
                                                phone ?? 'Not set',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: phone != null && phone!.isNotEmpty ? Colors.black : Colors.grey[500],
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Divider
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Divider(height: 1, color: Colors.grey),
                                  ),
                                  
                                  // Email Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Label section
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          'Email',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ':',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Value section
                                      Expanded(
                                        child: isEditing
                                            ? TextFormField(
                                                controller: _emailController,
                                                style: const TextStyle(color: Colors.black, fontSize: 16),
                                                decoration: const InputDecoration(
                                                  hintText: 'Enter your email',
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                                keyboardType: TextInputType.emailAddress,
                                                validator: (v) => v == null || v.isEmpty ? 'Email required' : null,
                                              )
                                            : Text(
                                                email ?? 'Not set',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: email != null && email!.isNotEmpty ? Colors.black : Colors.grey[500],
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Divider
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Divider(height: 1, color: Colors.grey),
                                  ),
                                  
                                  // Address Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Label section
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          'Address',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ':',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Value section
                                      Expanded(
                                        child: isEditing
                                            ? TextFormField(
                                                controller: _addressController,
                                                style: const TextStyle(color: Colors.black, fontSize: 16),
                                                decoration: const InputDecoration(
                                                  hintText: 'Enter your address',
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                                validator: (v) => v == null || v.isEmpty ? 'Address required' : null,
                                              )
                                            : Text(
                                                address ?? 'Not set',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: address != null && address!.isNotEmpty ? Colors.black : Colors.grey[500],
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                                        foregroundColor: Colors.black, // Text color for contrast
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
                                        foregroundColor: Colors.black, // Text color for contrast
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
            );
    
    // If embedded, just return the content without Scaffold
    if (widget.isEmbedded) {
      return content;
    }
    
    // Otherwise, return full page with navigation
    return Scaffold(
      appBar: OwnerAppBar(title: username != null && username!.isNotEmpty ? '@$username' : 'Profile'),
      endDrawer: OwnerDrawer(),
      body: content,
      bottomNavigationBar: OwnerNavBar(
        currentIndex: 3, // Profile index
        onTap: (index) {
          // Navigation handled by shared widget
        },
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