import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'shared_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final bool isEmbedded; // Whether this is embedded in another Scaffold
  
  const ProfileScreen({super.key, this.isEmbedded = false});

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
  String? username;
  bool isLoading = true;
  // ...existing code...
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  Uint8List? _selectedImageBytes;
  File? _selectedImageFile;
  String? _selectedImagePreviewName;
  bool _isCameraLoading = false;

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
    // Try to get the correct username (document ID)
    String? resolvedUsername = user.displayName;
    if (resolvedUsername == null || resolvedUsername.isEmpty) {
      // Fallback: try to get username from Firestore by email
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
    if (user == null) {
      setState(() { isLoading = false; });
      return;
    }
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

    String? uploadedUrl = imageUrl;
    try {
      // If a new image is selected, upload it first
      if (_selectedImageBytes != null || _selectedImageFile != null) {
        String? url;
        if (kIsWeb && _selectedImageBytes != null && _selectedImagePreviewName != null) {
          url = await _uploadImageToCloudinaryWeb(_selectedImageBytes!, _selectedImagePreviewName!);
        } else if (_selectedImageFile != null) {
          url = await _uploadImageToCloudinary(_selectedImageFile!);
        }
        if (url != null) {
          uploadedUrl = url;
        } else {
          setState(() { isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload failed. Please try again.')));
          return;
        }
      }
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
      // Always update all profile fields, including imageUrl
      await FirebaseFirestore.instance.collection('AppUsers').doc(username).update({
        'name': newName,
        'phone': newPhone,
        'email': newEmail,
        'profileImageUrl': uploadedUrl ?? '',
      });
      // Reload profile from Firestore to ensure UI is in sync and all fields (including image) are displayed
      await _loadProfile();
      setState(() {
        isEditing = false;
        _selectedImageBytes = null;
        _selectedImageFile = null;
        _selectedImagePreviewName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      return;
    }
    setState(() {
      isLoading = false;
      // Update originals after save (already set in _loadProfile)
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
    setState(() { _isCameraLoading = true; });
    await Future.delayed(const Duration(seconds: 1));
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      setState(() { _isCameraLoading = false; });
      return;
    }
    if (kIsWeb) {
      try {
        final imageBytes = await pickedFile.readAsBytes();
        final fileSize = imageBytes.length;
        if (fileSize > 20 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image must be below 20MB.')),
          );
          setState(() { _isCameraLoading = false; });
          return;
        }
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
        if (confirm != true) {
          setState(() { _isCameraLoading = false; });
          return;
        }
        setState(() {
          _selectedImageBytes = imageBytes;
          _selectedImageFile = null;
          _selectedImagePreviewName = pickedFile.name;
          _isCameraLoading = false;
        });
      } catch (e) {
        setState(() { _isCameraLoading = false; });
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
          setState(() { _isCameraLoading = false; });
          return;
        }
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
        if (confirm != true) {
          setState(() { _isCameraLoading = false; });
          return;
        }
        setState(() {
          _selectedImageFile = file;
          _selectedImageBytes = null;
          _selectedImagePreviewName = null;
          _isCameraLoading = false;
        });
      } catch (e) {
        setState(() { _isCameraLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing image: $e')),
        );
      }
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
                                  : (_selectedImageFile != null
                                      ? Image.file(_selectedImageFile!, fit: BoxFit.cover)
                                      : (imageUrl == null || imageUrl!.isEmpty
                                          ? Image.network(
                                              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
                                              fit: BoxFit.cover,
                                            )
                                          : Image.network(imageUrl!, fit: BoxFit.cover))),
                            ),
                          ),
                          if (isEditing)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: InkWell(
                                onTap: _isCameraLoading ? null : _pickAndUploadImage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: _isCameraLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.camera_alt, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if ((isEditing && (_selectedImageBytes != null || _selectedImageFile != null)))
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
                                      onPressed: isLoading ? null : _saveProfile,
                                      child: const Text('Save'),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                  child: SizedBox(
                                    width: 100,
                                    child: OutlinedButton(
                                      onPressed: isLoading ? null : _cancelEdit,
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
      appBar: CustomerAppBar(title: username != null && username!.isNotEmpty ? '@$username' : 'Profile'),
      endDrawer: const CustomerDrawer(),
      body: content,
      bottomNavigationBar: CustomerNavBar(
        currentIndex: 3, // Profile index
        onTap: (index) {
          // Navigation handled by shared widget
        },
      ),
    );
  }
}
