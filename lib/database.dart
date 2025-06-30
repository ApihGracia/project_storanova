import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final CollectionReference usersCollection = FirebaseFirestore.instance.collection('AppUsers');

  // CREATE: Save user info to Firestore with username as document ID
  Future<void> createUser({
    required String username,
    required String email,
    required String role,
    String? name,
    String? phone,
    String? profileImageUrl,
  }) async {
    await usersCollection.doc(username).set({
      'username': username,
      'email': email,
      'role': role,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    });
  }

  // READ: Get user document by username (username is now the document ID)
  Future<DocumentSnapshot?> getUserByUsername(String username) async {
    final doc = await usersCollection.doc(username).get();
    if (doc.exists) {
      return doc;
    }
    return null;
  }

  // UPDATE: Update user info by username
  Future<void> updateUser({
    required String username,
    String? name,
    String? email,
    String? phone,
    String? profileImageUrl,
  }) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (phone != null) data['phone'] = phone;
    if (profileImageUrl != null) data['profileImageUrl'] = profileImageUrl;
    if (data.isNotEmpty) {
      await usersCollection.doc(username).update(data);
    }
  }

  // DELETE: Delete user by username
  Future<void> deleteUser(String username) async {
    await usersCollection.doc(username).delete();
  }

  // Get user role by username (username is now the document ID)
  Future<String?> getUserRole(String username) async {
    final doc = await usersCollection.doc(username).get();
    if (doc.exists) {
      return doc['role'] as String?;
    }
    return null;
  }

  // CREATE: Register a new house for owner with username as document ID
  Future<void> createHouse({
    required String username,
    required String address,
    required String phone,
    required List<Map<String, dynamic>> prices,
    required DateTime availableFrom,
    required DateTime availableTo,
    List<String> imageUrls = const [],
  }) async {
    // Fetch owner name from AppUsers
    String name = '';
    final ownerDoc = await FirebaseFirestore.instance.collection('AppUsers').doc(username).get();
    if (ownerDoc.exists && ownerDoc.data() != null && ownerDoc.data()!['name'] != null) {
      name = ownerDoc.data()!['name'];
    }
    final houseData = {
      'owner': name,
      'address': address,
      'phone': phone,
      'prices': prices,
      'availableFrom': availableFrom.toIso8601String(),
      'availableTo': availableTo.toIso8601String(),
      'imageUrls': imageUrls,
    };
    await FirebaseFirestore.instance.collection('Houses').doc(username).set(houseData);
  }
}
