import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final CollectionReference usersCollection = FirebaseFirestore.instance.collection('AppUsers');
  final CollectionReference houseApplicationsCollection = FirebaseFirestore.instance.collection('HouseApplications');
  final CollectionReference approvedHousesCollection = FirebaseFirestore.instance.collection('ApprovedHouses');

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

  // HOUSE APPLICATION METHODS
  // CREATE: Submit house application for admin approval
  Future<void> submitHouseApplication({
    required String ownerUsername,
    required String address,
    required String phone,
    required List<Map<String, dynamic>> prices,
    required DateTime availableFrom,
    required DateTime availableTo,
    List<String> imageUrls = const [],
    String? description,
  }) async {
    // Get owner details
    final ownerDoc = await usersCollection.doc(ownerUsername).get();
    String ownerName = '';
    String ownerEmail = '';
    if (ownerDoc.exists) {
      final data = ownerDoc.data() as Map<String, dynamic>?;
      ownerName = data?['name'] ?? ownerUsername;
      ownerEmail = data?['email'] ?? '';
    }

    final applicationData = {
      'ownerUsername': ownerUsername,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'address': address,
      'phone': phone,
      'prices': prices,
      'availableFrom': availableFrom.toIso8601String(),
      'availableTo': availableTo.toIso8601String(),
      'imageUrls': imageUrls,
      'description': description ?? '',
      'status': 'pending', // pending, approved, rejected
      'submittedAt': DateTime.now().toIso8601String(),
      'reviewedAt': null,
      'reviewedBy': null,
      'reviewComments': null,
    };
    
    // Use owner username as document ID
    await houseApplicationsCollection.doc(ownerUsername).set(applicationData);
  }

  // READ: Get house applications (for admin)
  Future<List<Map<String, dynamic>>> getHouseApplications({String? status}) async {
    Query query = houseApplicationsCollection;
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    
    final snapshot = await query.get();
    
    // Get all applications and sort by submittedAt
    final applications = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // This will now be the owner username
      return data;
    }).toList();
    
    // Sort by submittedAt in descending order (newest first)
    applications.sort((a, b) {
      final aDate = DateTime.parse(a['submittedAt'] as String);
      final bDate = DateTime.parse(b['submittedAt'] as String);
      return bDate.compareTo(aDate); // Descending order
    });
    
    return applications;
  }

  // READ: Get house applications by owner
  Future<List<Map<String, dynamic>>> getHouseApplicationsByOwner(String ownerUsername) async {
    final doc = await houseApplicationsCollection.doc(ownerUsername).get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // This will be the owner username
      return [data];
    }
    
    return []; // Return empty list if no application found
  }

  // UPDATE: Approve or reject house application
  Future<void> reviewHouseApplication({
    required String applicationId, // This is now the owner username
    required String status, // 'approved' or 'rejected'
    required String reviewedBy,
    String? reviewComments,
  }) async {
    await houseApplicationsCollection.doc(applicationId).update({
      'status': status,
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewComments': reviewComments,
    });

    // If approved, move to approved houses collection
    if (status == 'approved') {
      final applicationDoc = await houseApplicationsCollection.doc(applicationId).get();
      if (applicationDoc.exists) {
        final data = applicationDoc.data() as Map<String, dynamic>;
        await approvedHousesCollection.doc(data['ownerUsername']).set({
          'owner': data['ownerName'],
          'ownerUsername': data['ownerUsername'],
          'address': data['address'],
          'phone': data['phone'],
          'prices': data['prices'],
          'availableFrom': data['availableFrom'],
          'availableTo': data['availableTo'],
          'imageUrls': data['imageUrls'],
          'description': data['description'],
          'approvedAt': DateTime.now().toIso8601String(),
          'approvedBy': reviewedBy,
          'isAvailable': true, // Default to available when first approved
          'statusUpdatedAt': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  // UPDATE: Update existing house application (only for pending or rejected applications)
  Future<void> updateHouseApplication({
    required String applicationId, // This is now the owner username
    required String address,
    required String phone,
    required List<Map<String, dynamic>> prices,
    required DateTime availableFrom,
    required DateTime availableTo,
    List<String> imageUrls = const [],
    String? description,
  }) async {
    final updateData = {
      'address': address,
      'phone': phone,
      'prices': prices,
      'availableFrom': availableFrom.toIso8601String(),
      'availableTo': availableTo.toIso8601String(),
      'imageUrls': imageUrls,
      'description': description ?? '',
      'status': 'pending', // Reset to pending when updated
      'submittedAt': DateTime.now().toIso8601String(), // Update submission time
      'reviewedAt': null, // Clear previous review
      'reviewedBy': null,
      'reviewComments': null,
    };
    
    await houseApplicationsCollection.doc(applicationId).update(updateData);
  }

  // READ: Get approved houses (for customer view)
  Future<List<Map<String, dynamic>>> getApprovedHouses() async {
    final snapshot = await approvedHousesCollection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // READ: Check if owner has approved house
  Future<bool> hasApprovedHouse(String ownerUsername) async {
    final doc = await approvedHousesCollection.doc(ownerUsername).get();
    return doc.exists;
  }

  // READ: Check if owner has existing application
  Future<bool> hasExistingApplication(String ownerUsername) async {
    final doc = await houseApplicationsCollection.doc(ownerUsername).get();
    return doc.exists;
  }

  // READ: Get owner's existing application
  Future<Map<String, dynamic>?> getOwnerApplication(String ownerUsername) async {
    final doc = await houseApplicationsCollection.doc(ownerUsername).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }
    return null;
  }

  // UPDATE: Toggle house availability status
  Future<void> updateHouseStatus({
    required String ownerUsername,
    required bool isAvailable,
  }) async {
    await approvedHousesCollection.doc(ownerUsername).update({
      'isAvailable': isAvailable,
      'statusUpdatedAt': DateTime.now().toIso8601String(),
    });
  }

  // READ: Get house status
  Future<bool> getHouseStatus(String ownerUsername) async {
    final doc = await approvedHousesCollection.doc(ownerUsername).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['isAvailable'] ?? true; // Default to available
    }
    return true;
  }

  // READ: Get available approved houses (for customer view) - only show available ones
  Future<List<Map<String, dynamic>>> getAvailableHouses() async {
    final snapshot = await approvedHousesCollection
        .where('isAvailable', isEqualTo: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
