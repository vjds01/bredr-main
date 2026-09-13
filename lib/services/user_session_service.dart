import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String googleServerClientId =
    '727589976733-8t902lckvith5f1dp5sk2omn5q8d7bcm.apps.googleusercontent.com';

class UserSessionService {
  UserSessionService._();

  static final UserSessionService instance = UserSessionService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;
  static const _sessionHintKey = 'breedr_had_authenticated_session';

  User? get currentUser => _auth.currentUser;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    await _googleSignIn.initialize(serverClientId: googleServerClientId);

    _googleInitialized = true;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?>
  getCurrentUserProfile() async {
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

  Future<bool> isCurrentUserVeterinaryAdmin() async {
    final user = currentUser;
    if (user?.email?.trim().toLowerCase() == 'breedr_vet@yahoo.com') {
      return true;
    }
    final profile = await getCurrentUserProfile();
    final role = profile?.data()?['role']?.toString().trim().toLowerCase();
    return role == 'veterinary_admin';
  }

  Future<bool> shouldAutoLogin() async {
    final result = await restoreSession();
    final user = result.user;

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
    return await _restoredUser() != null;
  }

  Future<SessionRestoreResult> restoreSession() async {
    try {
      final restoredUser = await _restoreFirebaseUser();
      if (restoredUser == null) return _restoreFailureResult();
      await _rememberAuthenticatedSession();
      return SessionRestoreResult.authenticated(restoredUser);
    } catch (error) {
      return _restoreFailureResult(error: error);
    }
  }

  /// Firebase can emit a temporary null auth state while Android restores its
  /// persisted credentials after a cold start. Waiting for the first non-null
  /// event prevents the splash screen from treating that brief state as a
  /// logout. A genuinely signed-out user simply reaches the timeout.
  Future<User?> _restoredUser() async {
    return (await restoreSession()).user;
  }

  Future<User?> _restoreFirebaseUser() async {
    final existingUser = currentUser;
    if (existingUser != null) return existingUser;

    return _auth
        .authStateChanges()
        .firstWhere((user) => user != null)
        .timeout(const Duration(seconds: 3), onTimeout: () => null);
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _rememberAuthenticatedSession();
    return credential;
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

    final firebaseCredential = await _auth.signInWithCredential(credential);
    await _rememberAuthenticatedSession();
    return firebaseCredential;
  }

  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // Email-only sessions do not always have a Google session to clear.
    }

    await _auth.signOut();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionHintKey);
  }

  Future<void> _rememberAuthenticatedSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_sessionHintKey, true);
  }

  Future<SessionRestoreResult> _restoreFailureResult({Object? error}) async {
    final preferences = await SharedPreferences.getInstance();
    final hadSession = preferences.getBool(_sessionHintKey) == true;
    return hadSession
        ? SessionRestoreResult.retryableFailure(error)
        : const SessionRestoreResult.signedOut();
  }
}

enum SessionRestoreStatus { authenticated, signedOut, retryableFailure }

class SessionRestoreResult {
  final SessionRestoreStatus status;
  final User? user;
  final Object? error;

  const SessionRestoreResult._(this.status, {this.user, this.error});

  const SessionRestoreResult.signedOut()
    : this._(SessionRestoreStatus.signedOut);

  factory SessionRestoreResult.authenticated(User user) =>
      SessionRestoreResult._(SessionRestoreStatus.authenticated, user: user);

  factory SessionRestoreResult.retryableFailure([Object? error]) =>
      SessionRestoreResult._(
        SessionRestoreStatus.retryableFailure,
        error: error,
      );

  bool get isAuthenticated => status == SessionRestoreStatus.authenticated;
  bool get shouldRetry => status == SessionRestoreStatus.retryableFailure;
}
