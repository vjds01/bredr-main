import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

const String googleServerClientId =
    '727589976733-8t902lckvith5f1dp5sk2omn5q8d7bcm.apps.googleusercontent.com';

class UserSessionService {
  UserSessionService._();

  static final UserSessionService instance = UserSessionService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    await _googleSignIn.initialize(
      serverClientId: googleServerClientId,
    );

    _googleInitialized = true;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getCurrentUserProfile() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    return _firestore.collection('users').doc(user.uid).get();
  }

  Future<bool> hasBreedrProfile() async {
    final profile = await getCurrentUserProfile();
    return profile?.exists ?? false;
  }

  Future<bool> isCurrentUserAdmin() async {
    final profile = await getCurrentUserProfile();
    final role = profile?.data()?['role']?.toString().trim().toLowerCase();
    return role == 'admin';
  }

  Future<bool> shouldAutoLogin() async {
    final user = currentUser ??
        await _auth.authStateChanges().first.timeout(
              const Duration(seconds: 2),
              onTimeout: () => null,
            );

    if (user == null) {
      return false;
    }

    try {
      final hasProfile = await hasBreedrProfile();
      if (!hasProfile) {
        return false;
      }

      return true;
    } catch (error) {
      // Keep the Firebase Auth session intact during temporary Firestore issues.
      return true;
    }
  }

  Future<bool> hasCurrentSession() async {
    if (currentUser != null) {
      return true;
    }

    final user = await _auth.authStateChanges().first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );

    return user != null;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw Exception('Google sign in is not supported on this platform');
    }

    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;

    if (googleAuth.idToken == null) {
      throw Exception('Google did not return an ID token');
    }

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // Email-only sessions do not always have a Google session to clear.
    }

    await _auth.signOut();
  }
}
