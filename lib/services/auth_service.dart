import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // LOGIN
  Future<void> login({
    required String email,
    required String password,
  }) async {

    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // SIGNUP
  Future<UserCredential> signUp({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {

    // Create Firebase Auth account
    UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Get generated UID
    String uid = userCredential.user!.uid;

    // Current timestamp
    Timestamp now = Timestamp.now();

    // Create Firestore user document
    await _firestore.collection('users').doc(uid).set({

      // AUTH
      'uid': uid,
      'email': email,
      'authProvider': 'email',

      // BASIC INFO
      'fullName': fullName,
      'username': username,
      'bio': '',

      // PHOTOS
      'profilePhoto': '',
      'additionalPhotos': [],

      // LOCATION
      'locationName': '',
      'latitude': null,
      'longitude': null,

      // HOME / HOUSEHOLD
      'homeType': '',
      'childrenAtHome': false,
      'otherPetsAtHome': false,

      // PROFILE STATUS
      'hasProfilePhoto': false,
      'profileCompleted': false,
      'isActive': true,

      // TIMESTAMPS
      'createdAt': now,
      'updatedAt': now,
    });

    return userCredential;
  }
}