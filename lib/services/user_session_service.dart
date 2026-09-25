import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  static const _sessionProviderKey = 'breedr_session_provider';
  static const _newSessionRestoreTimeout = Duration(seconds: 3);
  static const _knownSessionRestoreTimeout = Duration(seconds: 15);
  static const _googleRestoreTimeout = Duration(seconds: 8);

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
    final preferences = await SharedPreferences.getInstance();
    final hadSession = preferences.getBool(_sessionHintKey) == true;
    final providerHint = preferences.getString(_sessionProviderKey);

    try {
      var restoredUser = await _restoreFirebaseUser(
        timeout: hadSession
            ? _knownSessionRestoreTimeout
            : _newSessionRestoreTimeout,
      );

      if (restoredUser == null && hadSession && providerHint != 'password') {
        debugPrint(
          'Session restoration diagnostic: Firebase user unavailable; '
          'attempting lightweight Google restoration.',
        );
        restoredUser = await _restoreGoogleUser();
      }

      if (restoredUser == null) {
        if (hadSession) {
          await _clearSessionHints(preferences);
          debugPrint(
            'Session restoration diagnostic: saved credentials are no '
            'longer available; interactive sign-in is required.',
          );
          return const SessionRestoreResult.reauthenticationRequired();
        }
        return const SessionRestoreResult.signedOut();
      }
      await _rememberAuthenticatedSession(provider: _providerFor(restoredUser));
      debugPrint(
        'Session restoration diagnostic: restored uid=${restoredUser.uid}, '
        'provider=${_providerFor(restoredUser)}.',
      );
      return SessionRestoreResult.authenticated(restoredUser);
    } catch (error) {
      debugPrint('Session restoration diagnostic: retryable error=$error');
      return hadSession
          ? SessionRestoreResult.retryableFailure(error)
          : const SessionRestoreResult.signedOut();
    }
  }

  /// Firebase can emit a temporary null auth state while Android restores its
  /// persisted credentials after a cold start. Waiting for the first non-null
  /// event prevents the splash screen from treating that brief state as a
  /// logout. A genuinely signed-out user simply reaches the timeout.
  Future<User?> _restoredUser() async {
    return (await restoreSession()).user;
  }

  Future<User?> _restoreFirebaseUser({required Duration timeout}) async {
    final existingUser = currentUser;
    if (existingUser != null) return existingUser;

    // On some Android devices Firebase finishes restoring its encrypted auth
    // state several seconds after a cold process start. idTokenChanges emits
    // when that persisted credential becomes usable; importantly, this never
    // launches Google's interactive account chooser.
    final restoredUser = await _auth
        .idTokenChanges()
        .firstWhere((user) => user != null)
        .timeout(timeout, onTimeout: () => null);
    return restoredUser ?? currentUser;
  }

  Future<User?> _restoreGoogleUser() async {
    await _ensureGoogleInitialized();
    final restoration = _googleSignIn.attemptLightweightAuthentication();
    if (restoration == null) return null;

    final googleUser = await restoration.timeout(_googleRestoreTimeout);
    if (googleUser == null) return null;

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) return null;

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return (await _auth.signInWithCredential(credential)).user;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _rememberAuthenticatedSession(provider: 'password');
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
    await _rememberAuthenticatedSession(provider: 'google');
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
    await _clearSessionHints(preferences);
  }

  Future<void> _rememberAuthenticatedSession({String? provider}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_sessionHintKey, true);
    if (provider != null) {
      await preferences.setString(_sessionProviderKey, provider);
    }
  }

  Future<void> _clearSessionHints(SharedPreferences preferences) async {
    await preferences.remove(_sessionHintKey);
    await preferences.remove(_sessionProviderKey);
  }

  String _providerFor(User user) {
    return user.providerData.any(
          (provider) => provider.providerId == 'google.com',
        )
        ? 'google'
        : 'password';
  }
}

enum SessionRestoreStatus {
  authenticated,
  signedOut,
  reauthenticationRequired,
  retryableFailure,
}

class SessionRestoreResult {
  final SessionRestoreStatus status;
  final User? user;
  final Object? error;

  const SessionRestoreResult._(this.status, {this.user, this.error});

  const SessionRestoreResult.signedOut()
    : this._(SessionRestoreStatus.signedOut);

  const SessionRestoreResult.reauthenticationRequired()
    : this._(SessionRestoreStatus.reauthenticationRequired);

  factory SessionRestoreResult.authenticated(User user) =>
      SessionRestoreResult._(SessionRestoreStatus.authenticated, user: user);

  factory SessionRestoreResult.retryableFailure([Object? error]) =>
      SessionRestoreResult._(
        SessionRestoreStatus.retryableFailure,
        error: error,
      );

  bool get isAuthenticated => status == SessionRestoreStatus.authenticated;
  bool get requiresReauthentication =>
      status == SessionRestoreStatus.reauthenticationRequired;
  bool get shouldRetry => status == SessionRestoreStatus.retryableFailure;
}
