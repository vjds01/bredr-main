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

  Future<bool> shouldAutoLogin() async {
    final user = currentUser;

    if (user == null) {
      return false;
    }

    final hasProfile = await hasBreedrProfile();

    if (!hasProfile) {
      await signOut();
      return false;
    }

    return true;
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

  Future<void> sendPasswordResetLink(String email) {
    return _auth.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: 'https://breedr-3c5dc.web.app/usermgmt',
        handleCodeInApp: true,
        androidPackageName: 'com.example.breedr',
        androidInstallApp: false,
      ),
    );
  }

  Future<String> verifyPasswordResetCode(String resetCode) {
    return _auth.verifyPasswordResetCode(resetCode);
  }

  Future<void> confirmPasswordReset({
    required String resetCode,
    required String newPassword,
  }) {
    return _auth.confirmPasswordReset(
      code: resetCode,
      newPassword: newPassword,
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
