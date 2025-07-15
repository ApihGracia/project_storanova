import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final CollectionReference usersCollection = FirebaseFirestore.instance.collection('AppUsers');
  final CollectionReference houseApplicationsCollection = FirebaseFirestore.instance.collection('HouseApplications');
  final CollectionReference approvedHousesCollection = FirebaseFirestore.instance.collection('ApprovedHouses');

  // Helper method to retry Firestore operations with exponential backoff
  Future<T?> _retryFirestoreOperation<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          print('Firestore operation failed after $maxRetries attempts: $e');
          rethrow; // Re-throw the error on final failure
        }
        // Exponential backoff: wait 1s, then 2s, then 4s
        await Future.delayed(Duration(seconds: 1 << (retryCount - 1)));
        print('Retrying Firestore operation (attempt $retryCount/$maxRetries)...');
      }
    }
    return null;
  }

  // CREATE: Save user info to Firestore with username as document ID
  Future<void> createUser({
    required String username,
    required String email,
    required String role,
    String? name,
    String? phone,
    String? profileImageUrl,
  }) async {
    await _retryFirestoreOperation(() => usersCollection.doc(username).set({
      'username': username,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(), // Date joined
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    }));
  }

  // READ: Get user document by username (username is now the document ID)
  Future<DocumentSnapshot?> getUserByUsername(String username) async {
    print("DatabaseService: Getting user document for username: $username");
    try {
      final doc = await _retryFirestoreOperation(() => usersCollection.doc(username).get());
      if (doc != null && doc.exists) {
        print("DatabaseService: Found user document for $username");
        return doc;
      } else {
        print("DatabaseService: No user document found for $username");
        return null;
      }
    } catch (e) {
      print("DatabaseService: Error getting user document for $username: $e");
      return null;
    }
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

  // DELETE: Comprehensive user deletion from all collections
  Future<void> deleteUserCompletely(String username) async {
    try {
      print("Starting complete deletion for user: $username");
      
      // 1. Delete from AppUsers collection
      await usersCollection.doc(username).delete();
      print("Deleted user from AppUsers collection");
      
      // 2. Delete all notifications for this user
      final notificationsQuery = await FirebaseFirestore.instance
          .collection('Notifications')
          .where('username', isEqualTo: username)
          .get();
      
      for (final doc in notificationsQuery.docs) {
        await doc.reference.delete();
      }
      print("Deleted ${notificationsQuery.docs.length} notifications");
      
      // 3. Delete all appeals by this user
      final appealsQuery = await FirebaseFirestore.instance
          .collection('Appeals')
          .where('username', isEqualTo: username)
          .get();
      
      for (final doc in appealsQuery.docs) {
        await doc.reference.delete();
      }
      print("Deleted ${appealsQuery.docs.length} appeals");
      
      // 4. Delete all wishlists for this user
      final wishlistsQuery = await FirebaseFirestore.instance
          .collection('Wishlists')
          .where('customerUsername', isEqualTo: username)
          .get();
      
      for (final doc in wishlistsQuery.docs) {
        await doc.reference.delete();
      }
      print("Deleted ${wishlistsQuery.docs.length} wishlist items");
      
      // 5. Delete all bookings by this customer
      final customerBookingsQuery = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('customerUsername', isEqualTo: username)
          .get();
      
      for (final doc in customerBookingsQuery.docs) {
        await doc.reference.delete();
      }
      print("Deleted ${customerBookingsQuery.docs.length} customer bookings");
      
      // 6. Delete all bookings for houses owned by this user
      final ownerBookingsQuery = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('ownerUsername', isEqualTo: username)
          .get();
      
      for (final doc in ownerBookingsQuery.docs) {
        await doc.reference.delete();
      }
      print("Deleted ${ownerBookingsQuery.docs.length} owner bookings");
      
      // 7. Delete house if this user is an owner
      try {
        final houseDoc = await FirebaseFirestore.instance.collection('Houses').doc(username).get();
        if (houseDoc.exists) {
          await houseDoc.reference.delete();
          print("Deleted house registration");
        } else {
          print("No house registration found");
        }
      } catch (e) {
        print("Error checking/deleting house registration: $e");
      }
      
      // 8. Delete house application if this user is an owner
      try {
        final applicationDoc = await houseApplicationsCollection.doc(username).get();
        if (applicationDoc.exists) {
          await applicationDoc.reference.delete();
          print("Deleted house application");
        } else {
          print("No house application found");
        }
      } catch (e) {
        print("Error checking/deleting house application: $e");
      }
      
      // 9. Delete from approved houses if this user is an owner
      try {
        final approvedHouseDoc = await approvedHousesCollection.doc(username).get();
        if (approvedHouseDoc.exists) {
          await approvedHouseDoc.reference.delete();
          print("Deleted approved house");
        } else {
          print("No approved house found");
        }
      } catch (e) {
        print("Error checking/deleting approved house: $e");
      }
      
      print("Complete deletion finished successfully for user: $username");
    } catch (e) {
      print("Error during complete user deletion for $username: $e");
      throw Exception("Failed to completely delete user data: $e");
    }
  }

  // Get user role by username (username is now the document ID)
  Future<String?> getUserRole(String username) async {
    print("DatabaseService: Getting role for username: $username");
    try {
      final doc = await usersCollection.doc(username).get();
      if (doc.exists) {
        final role = doc['role'] as String?;
        print("DatabaseService: Found role for $username: $role");
        return role;
      } else {
        print("DatabaseService: No document found for username: $username");
        return null;
      }
    } catch (e) {
      print("DatabaseService: Error getting role for $username: $e");
      return null;
    }
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
    String? proofOfOwnershipUrl, // Added proof of ownership
    Map<String, bool>? paymentMethods, // New field
    String? maxItemQuantity, // New field
    String? pricePerItem, // New field
    bool offerPickupService = false, // New field
    String? pickupServiceCost, // New field
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
      'proofOfOwnershipUrl': proofOfOwnershipUrl, // Added proof of ownership
      'paymentMethods': paymentMethods ?? {}, // New field
      'maxItemQuantity': maxItemQuantity, // New field
      'pricePerItem': pricePerItem, // New field
      'offerPickupService': offerPickupService, // New field
      'pickupServiceCost': pickupServiceCost, // New field
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
          // New fields from the updated application form
          'paymentMethods': data['paymentMethods'] ?? {},
          'maxItemQuantity': data['maxItemQuantity'],
          'pricePerItem': data['pricePerItem'],
          'offerPickupService': data['offerPickupService'] ?? false,
          'pickupServiceCost': data['pickupServiceCost'],
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
    String? proofOfOwnershipUrl, // Added proof of ownership
    Map<String, bool>? paymentMethods, // New field
    String? maxItemQuantity, // New field
    String? pricePerItem, // New field
    bool offerPickupService = false, // New field
    String? pickupServiceCost, // New field
  }) async {
    final updateData = {
      'address': address,
      'phone': phone,
      'prices': prices,
      'availableFrom': availableFrom.toIso8601String(),
      'availableTo': availableTo.toIso8601String(),
      'imageUrls': imageUrls,
      'description': description ?? '',
      'proofOfOwnershipUrl': proofOfOwnershipUrl, // Added proof of ownership
      'paymentMethods': paymentMethods ?? {}, // New field
      'maxItemQuantity': maxItemQuantity, // New field
      'pricePerItem': pricePerItem, // New field
      'offerPickupService': offerPickupService, // New field
      'pickupServiceCost': pickupServiceCost, // New field
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

  // READ: Get approved house by owner username
  Future<Map<String, dynamic>?> getApprovedHouseByOwner(String ownerUsername) async {
    try {
      final doc = await approvedHousesCollection.doc(ownerUsername).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting approved house: $e');
      return null;
    }
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
    }).where((house) {
      // Filter out banned houses
      return !(house['isHouseBanned'] ?? false);
    }).toList();
  }

  // USER MANAGEMENT METHODS
  // READ: Get all users with optional role filter
  Future<List<Map<String, dynamic>>> getAllUsers({String? role}) async {
    Query query = usersCollection;
    if (role != null) {
      query = query.where('role', isEqualTo: role);
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // This will be the username
      return data;
    }).toList();
  }

  // UPDATE: Ban/Unban user
  Future<void> updateUserBanStatus({
    required String username,
    required bool isBanned,
    String? banReason,
    String? bannedBy,
  }) async {
    await usersCollection.doc(username).update({
      'isBanned': isBanned,
      'banReason': banReason,
      'bannedBy': bannedBy,
      'banDate': isBanned ? DateTime.now().toIso8601String() : null,
    });
  }

  // UPDATE: Ban house specifically
  Future<void> updateHouseBanStatus({
    required String ownerUsername,
    required bool isHouseBanned,
    String? houseBanReason,
    String? bannedBy,
  }) async {
    // Update approved house ban status
    final houseDoc = await approvedHousesCollection.doc(ownerUsername).get();
    if (houseDoc.exists) {
      await approvedHousesCollection.doc(ownerUsername).update({
        'isHouseBanned': isHouseBanned,
        'houseBanReason': houseBanReason,
        'houseBannedBy': bannedBy,
        'houseBanDate': isHouseBanned ? DateTime.now().toIso8601String() : null,
      });
    }
    
    // Also update the user's house ban status in AppUsers collection
    final userDoc = await usersCollection.doc(ownerUsername).get();
    if (userDoc.exists) {
      await usersCollection.doc(ownerUsername).update({
        'isHouseBanned': isHouseBanned,
        'houseBanReason': houseBanReason,
        'houseBannedBy': bannedBy,
        'houseBanDate': isHouseBanned ? DateTime.now().toIso8601String() : null,
      });
    }
  }

  // CREATE: Add notification for user with meaningful document ID
  Future<void> addNotification({
    required String username,
    required String title,
    required String message,
    required String type, // 'ban', 'warning', 'info', 'appeal', 'booking'
    String? relatedDocumentId, // For appeals, house bookings, etc.
  }) async {
    // Get the next index for this type and user
    final existingSnapshot = await FirebaseFirestore.instance
        .collection('Notifications')
        .where('username', isEqualTo: username)
        .where('type', isEqualTo: type)
        .get();
    
    final nextIndex = existingSnapshot.docs.length + 1;
    final documentId = '${type}_${username}_$nextIndex';
    
    await FirebaseFirestore.instance.collection('Notifications').doc(documentId).set({
      'username': username,
      'title': title,
      'message': message,
      'type': type,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
      'relatedDocumentId': relatedDocumentId,
    });
  }

  // CREATE: Submit appeal for banned user
  Future<void> submitAppeal({
    required String username,
    required String appealReason,
    required String banType, // 'user' or 'house'
  }) async {
    // Get the next appeal index for this user
    final existingAppeals = await FirebaseFirestore.instance
        .collection('Appeals')
        .where('username', isEqualTo: username)
        .get();
    
    final nextIndex = existingAppeals.docs.length + 1;
    final appealId = 'appeal_${username}_$nextIndex';
    
    await FirebaseFirestore.instance.collection('Appeals').doc(appealId).set({
      'username': username,
      'appealReason': appealReason,
      'banType': banType,
      'status': 'pending', // pending, approved, rejected
      'submittedAt': DateTime.now().toIso8601String(),
      'reviewedAt': null,
      'reviewedBy': null,
      'reviewComments': null,
    });

    // Add notification to user
    await addNotification(
      username: username,
      title: 'Appeal Submitted',
      message: 'Your appeal has been submitted and is being reviewed by the admin.',
      type: 'appeal',
      relatedDocumentId: appealId,
    );

    // Add notification to admin
    await addNotification(
      username: 'admin', // Assuming admin username is 'admin'
      title: 'New Appeal Submitted',
      message: 'User $username has submitted an appeal for review.',
      type: 'appeal',
      relatedDocumentId: appealId,
    );
  }

  // READ: Get appeals for admin
  Future<List<Map<String, dynamic>>> getAllAppeals({String? status}) async {
    Query query = FirebaseFirestore.instance.collection('Appeals');
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    
    final snapshot = await query.get();
    final appeals = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    
    // Sort by submittedAt descending (newest first)
    appeals.sort((a, b) {
      final aDate = DateTime.parse(a['submittedAt']);
      final bDate = DateTime.parse(b['submittedAt']);
      return bDate.compareTo(aDate);
    });
    
    return appeals;
  }

  // UPDATE: Review appeal
  Future<void> reviewAppeal({
    required String appealId,
    required String status, // 'approved' or 'rejected'
    required String reviewedBy,
    String? reviewComments,
  }) async {
    // Get the appeal document
    final appealDoc = await FirebaseFirestore.instance
        .collection('Appeals')
        .doc(appealId)
        .get();
    
    if (!appealDoc.exists) return;
    
    final appealData = appealDoc.data() as Map<String, dynamic>;
    final username = appealData['username'] as String;
    final banType = appealData['banType'] as String;
    
    // Update appeal status
    await FirebaseFirestore.instance.collection('Appeals').doc(appealId).update({
      'status': status,
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewComments': reviewComments,
    });

    // If approved, unban the user/house
    if (status == 'approved') {
      if (banType == 'user') {
        await updateUserBanStatus(
          username: username,
          isBanned: false,
          banReason: null,
          bannedBy: reviewedBy,
        );
      } else if (banType == 'house') {
        await updateHouseBanStatus(
          ownerUsername: username,
          isHouseBanned: false,
          houseBanReason: null,
          bannedBy: reviewedBy,
        );
      }
      
      // Notify user of successful appeal
      await addNotification(
        username: username,
        title: 'Appeal Approved',
        message: 'Your appeal has been approved. ${banType == 'user' ? 'Your account' : 'Your house'} has been unbanned.',
        type: 'appeal',
        relatedDocumentId: appealId,
      );
    } else {
      // Notify user of rejected appeal
      await addNotification(
        username: username,
        title: 'Appeal Rejected',
        message: 'Your appeal has been rejected. ${reviewComments != null ? 'Reason: $reviewComments' : ''}',
        type: 'appeal',
        relatedDocumentId: appealId,
      );
    }
  }

  // READ: Get notifications for user
  Future<List<Map<String, dynamic>>> getUserNotifications(String username) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Notifications')
        .where('username', isEqualTo: username)
        .get();
        
    List<Map<String, dynamic>> notifications = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    
    // Sort by createdAt in descending order (newest first)
    notifications.sort((a, b) {
      final aDate = DateTime.parse(a['createdAt']);
      final bDate = DateTime.parse(b['createdAt']);
      return bDate.compareTo(aDate);
    });
    
    return notifications;
  }

  // UPDATE: Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('Notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // READ: Get unread notification count for user
  Future<int> getUnreadNotificationCount(String username) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Notifications')
        .where('username', isEqualTo: username)
        .where('isRead', isEqualTo: false)
        .get();
        
    return snapshot.docs.length;
  }

  // DELETE: Delete notification by ID
  Future<void> deleteNotification(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('Notifications')
        .doc(notificationId)
        .delete();
  }

  // WISHLIST METHODS
  
  // Add house to user's wishlist
  Future<void> addToWishlist({
    required String username,
    required String houseId,
    required String houseName,
    required String ownerUsername,
    String? imageUrl,
  }) async {
    final wishlistDoc = '${username}_${houseId}';
    await FirebaseFirestore.instance.collection('Wishlists').doc(wishlistDoc).set({
      'username': username,
      'houseId': houseId,
      'houseName': houseName,
      'ownerUsername': ownerUsername,
      'imageUrl': imageUrl,
      'addedAt': DateTime.now().toIso8601String(),
    });
  }

  // Remove house from user's wishlist
  Future<void> removeFromWishlist({
    required String username,
    required String houseId,
  }) async {
    final wishlistDoc = '${username}_${houseId}';
    await FirebaseFirestore.instance.collection('Wishlists').doc(wishlistDoc).delete();
  }

  // Check if house is in user's wishlist
  Future<bool> isInWishlist({
    required String username,
    required String houseId,
  }) async {
    final wishlistDoc = '${username}_${houseId}';
    final doc = await FirebaseFirestore.instance.collection('Wishlists').doc(wishlistDoc).get();
    return doc.exists;
  }

  // Get user's wishlist
  Future<List<Map<String, dynamic>>> getUserWishlist(String username) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Wishlists')
        .where('username', isEqualTo: username)
        .orderBy('addedAt', descending: true)
        .get();

    List<Map<String, dynamic>> wishlistItems = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      
      // Get house details from ApprovedHouses
      final houseDoc = await approvedHousesCollection.doc(data['houseId']).get();
      if (houseDoc.exists) {
        final houseData = houseDoc.data() as Map<String, dynamic>;
        
        // Only include if house is still available and not banned
        if (houseData['isAvailable'] == true && (houseData['isHouseBanned'] ?? false) == false) {
          wishlistItems.add({
            'id': doc.id,
            'houseId': data['houseId'],
            'houseName': data['houseName'],
            'ownerUsername': data['ownerUsername'],
            'addedAt': data['addedAt'],
            'houseData': houseData,
          });
        }
      }
    }
    return wishlistItems;
  }

  // BOOKING METHODS

  // Create a booking
  Future<String> createBooking({
    required String customerUsername,
    required String ownerUsername,
    required String houseId,
    required String houseAddress, // Changed from houseName to houseAddress
    required DateTime checkIn,
    required DateTime checkOut,
    required double totalPrice,
    required String priceBreakdown,
    String? specialRequests,
    String? paymentMethod,
    bool usePickupService = false,
    int? quantity,
    double? pricePerItem, // Store the original price per item
    double? pickupServiceCost, // Store the original pickup service cost
  }) async {
    // Generate booking ID
    final bookingSnapshot = await FirebaseFirestore.instance
        .collection('Bookings')
        .where('customerUsername', isEqualTo: customerUsername)
        .get();
    
    final nextIndex = bookingSnapshot.docs.length + 1;
    final bookingId = 'booking_${customerUsername}_$nextIndex';

    await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).set({
      'customerUsername': customerUsername,
      'ownerUsername': ownerUsername,
      'houseId': houseId,
      'houseAddress': houseAddress, // Store the house address
      'houseName': houseAddress, // Keep for backward compatibility
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut.toIso8601String(),
      'totalPrice': totalPrice,
      'priceBreakdown': priceBreakdown,
      'specialRequests': specialRequests,
      'paymentMethod': paymentMethod,
      'usePickupService': usePickupService,
      'quantity': quantity,
      'pricePerItem': pricePerItem, // Store for accurate editing calculations
      'pickupServiceCost': pickupServiceCost, // Store for accurate editing calculations
      'status': 'pending', // pending, approved, rejected, cancelled
      'createdAt': DateTime.now().toIso8601String(),
      'reviewedAt': null,
      'reviewedBy': null,
      'reviewComments': null,
    });

    // Send notification to customer
    await addNotification(
      username: customerUsername,
      title: 'Booking Submitted',
      message: 'Your booking for $houseAddress has been submitted and is waiting for owner review.',
      type: 'booking',
      relatedDocumentId: bookingId,
    );

    // Send notification to owner
    await addNotification(
      username: ownerUsername,
      title: 'New Booking Request',
      message: 'You have a new booking request for $houseAddress from $customerUsername.',
      type: 'booking',
      relatedDocumentId: bookingId,
    );

    return bookingId;
  }

  // Get user's bookings
  Future<List<Map<String, dynamic>>> getUserBookings(String username) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Bookings')
        .where('customerUsername', isEqualTo: username)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Get owner's booking requests
  Future<List<Map<String, dynamic>>> getOwnerBookingRequests(String ownerUsername) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('ownerUsername', isEqualTo: ownerUsername)
          .get();

      List<Map<String, dynamic>> bookings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by createdAt in memory instead of using orderBy to avoid index requirement
      bookings.sort((a, b) {
        try {
          final aDate = DateTime.parse(a['createdAt']);
          final bDate = DateTime.parse(b['createdAt']);
          return bDate.compareTo(aDate); // Descending order (newest first)
        } catch (e) {
          return 0;
        }
      });

      return bookings;
    } catch (e) {
      print('Error loading owner booking requests: $e');
      return [];
    }
  }

  // Get all customers for an owner
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('AppUsers')
        .where('role', isEqualTo: 'Customer')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['username'] = doc.id;
      return data;
    }).toList();
  }

  // Get pending booking applications for an owner
  Future<List<Map<String, dynamic>>> getOwnerPendingBookings(String ownerUsername) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('ownerUsername', isEqualTo: ownerUsername)
          .where('status', isEqualTo: 'pending')
          .get();

      List<Map<String, dynamic>> bookings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by createdAt in memory instead of using orderBy to avoid index requirement
      bookings.sort((a, b) {
        try {
          final aDate = DateTime.parse(a['createdAt']);
          final bDate = DateTime.parse(b['createdAt']);
          return bDate.compareTo(aDate); // Descending order (newest first)
        } catch (e) {
          return 0;
        }
      });

      return bookings;
    } catch (e) {
      print('Error loading pending bookings: $e');
      return [];
    }
  }

  // Update booking status
  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
    required String reviewedBy,
    String? reviewComments,
  }) async {
    await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).update({
      'status': status,
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewComments': reviewComments,
    });

    // Get booking details for notification
    final bookingDoc = await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).get();
    if (bookingDoc.exists) {
      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final customerUsername = bookingData['customerUsername'];
      final houseAddress = bookingData['houseAddress'] ?? bookingData['houseName'] ?? 'this address';

      // Send notification to customer
      String title = '';
      String message = '';
      
      switch (status) {
        case 'approved':
          title = 'Booking Approved';
          final paymentMethod = bookingData['paymentMethod']?.toString().toLowerCase();
          if (paymentMethod == 'cash') {
            message = 'Your booking for $houseAddress has been approved! You can proceed with cash payment during service.';
          } else {
            message = 'Your booking for $houseAddress has been approved! Please proceed with payment to confirm your reservation.';
          }
          break;
        case 'rejected':
          title = 'Booking Rejected';
          message = 'Your booking for $houseAddress has been rejected. ${reviewComments != null ? "Reason: $reviewComments" : ""}';
          break;
        case 'cancelled':
          title = 'Booking Cancelled';
          message = 'Your booking for $houseAddress has been cancelled.';
          break;
      }

      if (title.isNotEmpty) {
        await addNotification(
          username: customerUsername,
          title: title,
          message: message,
          type: 'booking',
          relatedDocumentId: bookingId,
        );
      }
    }
  }

  // Update a pending booking
  Future<void> updateBooking({
    required String bookingId,
    required String customerUsername,
    required String ownerUsername,
    required String houseId,
    required String houseName,
    required DateTime checkIn,
    required DateTime checkOut,
    required double totalPrice,
    required String priceBreakdown,
    String? specialRequests,
    String? paymentMethod,
    bool usePickupService = false,
    int? quantity,
  }) async {
    // Check if booking is still pending
    final bookingDoc = await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      throw Exception('Booking not found');
    }
    
    final bookingData = bookingDoc.data() as Map<String, dynamic>;
    if (bookingData['status'] != 'pending') {
      throw Exception('Can only edit pending bookings');
    }
    
    await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).update({
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut.toIso8601String(),
      'totalPrice': totalPrice,
      'priceBreakdown': priceBreakdown,
      'specialRequests': specialRequests,
      'paymentMethod': paymentMethod,
      'usePickupService': usePickupService,
      'quantity': quantity,
    });
  }

  // Delete/cancel a pending booking
  Future<void> deleteBooking(String bookingId) async {
    // Check if booking is still pending
    final bookingDoc = await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      throw Exception('Booking not found');
    }
    
    final bookingData = bookingDoc.data() as Map<String, dynamic>;
    if (bookingData['status'] != 'pending') {
      throw Exception('Can only delete pending bookings');
    }
    
    // Delete the booking
    await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).delete();
    
    // Send notification to owner about cancellation
    final ownerUsername = bookingData['ownerUsername'];
    final houseAddress = bookingData['houseAddress'] ?? bookingData['houseName'] ?? 'this address';
    final customerUsername = bookingData['customerUsername'];
    
    await addNotification(
      username: ownerUsername,
      title: 'Booking Cancelled',
      message: 'The booking request for $houseAddress from $customerUsername has been cancelled.',
      type: 'booking',
      relatedDocumentId: bookingId,
    );
  }

  // Get booking by ID
  Future<Map<String, dynamic>?> getBookingById(String bookingId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Bookings')
          .doc(bookingId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error fetching booking: $e');
      return null;
    }
  }

  // Update payment status for a booking
  Future<void> updatePaymentStatus({
    required String bookingId,
    required String paymentStatus,
    String? paymentReceivedBy,
  }) async {
    final updateData = {
      'paymentStatus': paymentStatus,
      'paymentUpdatedAt': DateTime.now().toIso8601String(),
    };
    
    if (paymentReceivedBy != null) {
      updateData['paymentReceivedBy'] = paymentReceivedBy;
      updateData['paymentReceivedAt'] = DateTime.now().toIso8601String();
    }
    
    await FirebaseFirestore.instance
        .collection('Bookings')
        .doc(bookingId)
        .update(updateData);
  }

  // Cancel a booking
  Future<void> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    String? cancelReason,
  }) async {
    await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).update({
      'status': 'cancelled',
      'cancelledAt': DateTime.now().toIso8601String(),
      'cancelledBy': cancelledBy,
      'cancelReason': cancelReason,
    });

    // Get booking details for notification
    final bookingDoc = await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).get();
    if (bookingDoc.exists) {
      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final customerUsername = bookingData['customerUsername'];
      final ownerUsername = bookingData['ownerUsername'];
      final houseAddress = bookingData['houseAddress'] ?? bookingData['houseName'] ?? 'this address';

      // Send notification to owner
      await addNotification(
        username: ownerUsername,
        title: 'Booking Cancelled',
        message: 'The booking for $houseAddress has been cancelled by $customerUsername.',
        type: 'booking',
        relatedDocumentId: bookingId,
      );

      // Send notification to customer
      await addNotification(
        username: customerUsername,
        title: 'Booking Cancelled',
        message: 'Your booking for $houseAddress has been cancelled.',
        type: 'booking',
        relatedDocumentId: bookingId,
      );
    }
  }

  // Complete payment for a booking
  Future<void> completePayment({
    required String bookingId,
  }) async {
    await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).update({
      'paymentStatus': 'completed',
      'paymentCompletedAt': DateTime.now().toIso8601String(),
    });

    // Get booking details for notification
    final bookingDoc = await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).get();
    if (bookingDoc.exists) {
      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final customerUsername = bookingData['customerUsername'];
      final ownerUsername = bookingData['ownerUsername'];
      final houseAddress = bookingData['houseAddress'] ?? bookingData['houseName'] ?? 'this address';

      // Send notification to owner
      await addNotification(
        username: ownerUsername,
        title: 'Payment Completed',
        message: 'Payment for the booking at $houseAddress has been completed by $customerUsername.',
        type: 'booking',
        relatedDocumentId: bookingId,
      );

      // Send notification to customer
      await addNotification(
        username: customerUsername,
        title: 'Payment Successful',
        message: 'Your payment for $houseAddress has been completed successfully. Your booking is now confirmed!',
        type: 'booking',
        relatedDocumentId: bookingId,
      );
    }
  }

  // Get approved bookings awaiting payment for a customer
  Future<List<Map<String, dynamic>>> getCustomerApprovedBookingsAwaitingPayment(String customerUsername) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Bookings')
          .where('customerUsername', isEqualTo: customerUsername)
          .where('status', isEqualTo: 'approved')
          .get();

      List<Map<String, dynamic>> bookings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Filter for non-cash payments that haven't been completed
      bookings = bookings.where((booking) {
        final paymentMethod = booking['paymentMethod']?.toString().toLowerCase();
        final paymentStatus = booking['paymentStatus']?.toString().toLowerCase();
        return paymentMethod != 'cash' && paymentStatus != 'completed';
      }).toList();

      // Sort by approvedAt/reviewedAt in descending order
      bookings.sort((a, b) {
        try {
          final aDate = DateTime.parse(a['reviewedAt'] ?? a['createdAt']);
          final bDate = DateTime.parse(b['reviewedAt'] ?? b['createdAt']);
          return bDate.compareTo(aDate);
        } catch (e) {
          return 0;
        }
      });

      return bookings;
    } catch (e) {
      print('Error loading approved bookings awaiting payment: $e');
      return [];
    }
  }

  // Update storage status for a booking
  Future<void> updateStorageStatus({
    required String bookingId,
    required String storageStatus, // 'not_stored', 'stored', 'picked_up'
    required String updatedBy,
  }) async {
    await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).update({
      'storageStatus': storageStatus,
      'storageStatusUpdatedAt': DateTime.now().toIso8601String(),
      'storageStatusUpdatedBy': updatedBy,
    });

    // Get booking details for notification
    final bookingDoc = await FirebaseFirestore.instance.collection('Bookings').doc(bookingId).get();
    if (bookingDoc.exists) {
      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final customerUsername = bookingData['customerUsername'];
      final houseAddress = bookingData['houseAddress'] ?? bookingData['houseName'] ?? 'this address';

      String title = '';
      String message = '';

      switch (storageStatus) {
        case 'stored':
          title = 'Items Stored';
          message = 'Your items have been stored at $houseAddress. They are safe and ready for pickup when you need them.';
          break;
        case 'picked_up':
          title = 'Items Picked Up';
          message = 'Your items from $houseAddress have been marked as picked up. Thank you for using StoraNova!';
          break;
      }

      if (title.isNotEmpty) {
        await addNotification(
          username: customerUsername,
          title: title,
          message: message,
          type: 'booking',
          relatedDocumentId: bookingId,
        );
      }
    }
  }

  // Utility method for parsing datetime from either string or Firestore Timestamp
  static DateTime parseDateTime(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now(); // Fallback to current time
    }
    
    if (dateValue is Timestamp) {
      // Handle Firestore Timestamp
      return dateValue.toDate();
    } else if (dateValue is String) {
      // Handle ISO8601 string
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        print('Error parsing date string: $dateValue, error: $e');
        return DateTime.now(); // Fallback to current time
      }
    } else if (dateValue is DateTime) {
      // Already a DateTime object
      return dateValue;
    } else {
      print('Unknown date format: $dateValue (${dateValue.runtimeType})');
      return DateTime.now(); // Fallback to current time
    }
  }
}
