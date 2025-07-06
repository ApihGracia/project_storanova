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
    print("DatabaseService: Getting user document for username: $username");
    try {
      final doc = await usersCollection.doc(username).get();
      if (doc.exists) {
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
    String? proofOfOwnershipUrl, // Added proof of ownership
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
    required String houseName,
    required DateTime checkIn,
    required DateTime checkOut,
    required double totalPrice,
    required String priceBreakdown,
    String? specialRequests,
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
      'houseName': houseName,
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut.toIso8601String(),
      'totalPrice': totalPrice,
      'priceBreakdown': priceBreakdown,
      'specialRequests': specialRequests,
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
      message: 'Your booking for $houseName has been submitted and is waiting for owner review.',
      type: 'booking',
      relatedDocumentId: bookingId,
    );

    // Send notification to owner
    await addNotification(
      username: ownerUsername,
      title: 'New Booking Request',
      message: 'You have a new booking request for $houseName from $customerUsername.',
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
    final snapshot = await FirebaseFirestore.instance
        .collection('Bookings')
        .where('ownerUsername', isEqualTo: ownerUsername)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
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
      final houseName = bookingData['houseName'];

      // Send notification to customer
      String title = '';
      String message = '';
      
      switch (status) {
        case 'approved':
          title = 'Booking Approved';
          message = 'Your booking for $houseName has been approved by the owner.';
          break;
        case 'rejected':
          title = 'Booking Rejected';
          message = 'Your booking for $houseName has been rejected. ${reviewComments != null ? "Reason: $reviewComments" : ""}';
          break;
        case 'cancelled':
          title = 'Booking Cancelled';
          message = 'Your booking for $houseName has been cancelled.';
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
}
