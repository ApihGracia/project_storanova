import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      print("AuthService: Attempting to sign in with email: $email");
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("AuthService: Sign in successful, user: ${result.user?.email}");
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("Error signing in: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      print("Unexpected error signing in: $e");
      return null;
    }
  }

  // Register with email and password
  Future<User?> registerWithEmailPassword(
      String email, String password, String role) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("Error registering: ${e.code} - ${e.message}");
      return null;
    }
  }

  // Get user role from Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('AppUsers').doc(uid).get();
      return doc['role'];
    } catch (e) {
      print("Error getting user role: $e");
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print("User signed out successfully");
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  Future<void> sendPasswordResetEmail(String email) async {
  await _auth.sendPasswordResetEmail(email: email);
}
}