import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'cust_dashboard.dart';
import 'main.dart';

// StoraNovaNavBar is now imported from main.dart


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Remove duplicate method declarations
  bool isEditing = false;
  // For cancel: keep a copy of original values
  String? _originalName;
  String? _originalPhone;
  String? _originalEmail;
  String? imageUrl;
  String? name;
  String? role;
  String? phone;
  String? email;
  bool isLoading = true;
  int _currentIndex = 4; // Profile tab
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

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
    final doc = await FirebaseFirestore.instance.collection('AppUsers').doc(user.displayName ?? user.email?.split('@')[0]).get();
    final data = doc.data();
    setState(() {
      imageUrl = data?['profileImageUrl'];
      name = data?['name'] ?? '';
      role = data?['role'] ?? '';
      phone = data?['phone'] ?? '';
      email = data?['email'] ?? user.email ?? '';
      _nameController.text = name ?? '';
      _phoneController.text = phone ?? '';
      _emailController.text = email ?? '';
      isLoading = false;
      // Save originals for cancel
      _originalName = name ?? '';
      _originalPhone = phone ?? '';
      _originalEmail = email ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<String?> _showPasswordDialog() async {
    final TextEditingController _pwController = TextEditingController();
    String? result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-authenticate'),
        content: TextField(
          controller: _pwController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Enter your password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, _pwController.text), child: const Text('Confirm')),
        ],
      ),
    );
    _pwController.dispose();
    return result;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { isLoading = true; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final newName = _nameController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newEmail = _emailController.text.trim();
    bool emailChanged = newEmail != (email ?? '');

    // Get the correct username (document ID)
    String? username;
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      username = user.displayName;
    } else {
      // Fallback: try to get username from Firestore by email
      final userDoc = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (userDoc.docs.isNotEmpty) {
        username = userDoc.docs.first.id;
      }
    }
    if (username == null) {
      setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not determine your username.')),
      );
      return;
    }

    try {
      if (emailChanged) {
        // Re-authenticate required
        String? password = await _showPasswordDialog();
        if (password == null) {
          setState(() { isLoading = false; });
          return;
        }
        AuthCredential credential = EmailAuthProvider.credential(email: email!, password: password);
        await user.reauthenticateWithCredential(credential);
        await user.updateEmail(newEmail);
      }
      await FirebaseFirestore.instance.collection('AppUsers').doc(username).update({
        'name': newName,
        'phone': newPhone,
        'email': newEmail,
      });
      setState(() {
        name = newName;
        phone = newPhone;
        email = newEmail;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
    setState(() {
      isLoading = false;
      isEditing = false;
      // Update originals after save
      _originalName = _nameController.text.trim();
      _originalPhone = _phoneController.text.trim();
      _originalEmail = _emailController.text.trim();
    });
  }

  void _startEdit() {
    setState(() {
      isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      isEditing = false;
      // Restore original values
      _nameController.text = _originalName ?? '';
      _phoneController.text = _originalPhone ?? '';
      _emailController.text = _originalEmail ?? '';
    });
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    final cloudName = 'dxeejx1hq';
    final uploadPreset = 'StoraNova';
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
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
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (kIsWeb) {
      // Web: use bytes
      final imageBytes = await pickedFile.readAsBytes();
      final fileSize = imageBytes.length;
      if (fileSize > 20 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be below 20MB.')),
        );
        return;
      }
      // Show preview and confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Image'),
          content: SizedBox(
            width: 200,
            height: 200,
            child: Image.memory(imageBytes, fit: BoxFit.cover),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Use this image'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      setState(() { isLoading = true; });
      String? uploadedUrl = await _uploadImageToCloudinaryWeb(imageBytes, pickedFile.name);
      if (uploadedUrl != null) {
        setState(() {
          imageUrl = uploadedUrl;
        });
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('AppUsers').doc(user.displayName ?? user.email?.split('@')[0]).update({
            'profileImageUrl': uploadedUrl,
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed.')),
        );
      }
      setState(() { isLoading = false; });
    } else {
      // Mobile/desktop: use File
      final file = File(pickedFile.path);
      final fileSize = await file.length();
      if (fileSize > 20 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be below 20MB.')),
        );
        return;
      }
      // Show preview and confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Image'),
          content: SizedBox(
            width: 200,
            height: 200,
            child: Image.file(file, fit: BoxFit.cover),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Use this image'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      setState(() { isLoading = true; });
      String? uploadedUrl = await _uploadImageToCloudinary(file);
      if (uploadedUrl != null) {
        setState(() {
          imageUrl = uploadedUrl;
        });
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('AppUsers').doc(user.displayName ?? user.email?.split('@')[0]).update({
            'profileImageUrl': uploadedUrl,
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed.')),
        );
      }
      setState(() { isLoading = false; });
    }
  }

  // Add this for web upload
  Future<String?> _uploadImageToCloudinaryWeb(Uint8List imageBytes, String filename) async {
    final cloudName = 'dxeejx1hq';
    final uploadPreset = 'StoraNova';
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));
    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      final data = jsonDecode(respStr);
      return data['secure_url'];
    } else {
      print('Cloudinary upload failed: ${response.statusCode}');
      print('Cloudinary error response: $respStr');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFADD8E6),
        elevation: 0,
        title: Text(name != null && name!.isNotEmpty ? name! : 'Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
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
                              child: imageUrl == null || imageUrl!.isEmpty
                                  ? Image.network(
                                      'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(imageUrl!, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: isEditing ? _pickAndUploadImage : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isEditing ? Colors.blue : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(Icons.camera_alt, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Name required' : null,
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              if (isEditing) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Contact admin to change your role.')),
                                );
                              }
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                initialValue: role ?? '',
                                enabled: false,
                                decoration: const InputDecoration(
                                  labelText: 'Role',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            enabled: isEditing,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            enabled: isEditing,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Email required' : null,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              if (!isEditing)
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _startEdit,
                                    child: const Text('Edit'),
                                  ),
                                ),
                              if (isEditing) ...[
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _saveProfile,
                                    child: const Text('Save'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isLoading ? null : _cancelEdit,
                                    child: const Text('Cancel'),
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
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
          if (index == 2) {
            // Home (dashboard)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => CustHomePage()),
            );
          } else if (index == 1) {
            // Wishlist
            Navigator.pushReplacementNamed(context, '/wishlist');
          } else if (index == 4) {
            // Already on profile
          }
          // Add navigation for other tabs as needed
        },
      ),
    );
  }


  // Removed duplicate _profileField. Use ProfileRow instead.
}
