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
  static const _sessionUidKey = 'breedr_session_uid';
  static const _sessionEmailKey = 'breedr_session_email';
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
    final expectedUid = preferences.getString(_sessionUidKey);
    final expectedEmail = preferences.getString(_sessionEmailKey);

    try {
      var restoredUser = await _restoreFirebaseUser(
        timeout: hadSession
            ? _knownSessionRestoreTimeout
            : _newSessionRestoreTimeout,
      );

      if (restoredUser == null && hadSession && providerHint == 'google') {
        debugPrint(
          'Session restoration diagnostic: Firebase user unavailable; '
          'attempting lightweight Google restoration.',
        );
        try {
          restoredUser = await _restoreGoogleUser(
            expectedUid: expectedUid,
            expectedEmail: expectedEmail,
          );
        } on GoogleSessionConfirmationRequired catch (error) {
          debugPrint(
            'Session restoration diagnostic: Google account confirmation '
            'required (${error.reason}).',
          );
          return SessionRestoreResult.googleConfirmationRequired(
            expectedEmail: expectedEmail,
          );
        }
      }

      if (restoredUser == null) {
        if (hadSession) {
          debugPrint(
            'Session restoration diagnostic: Firebase credentials are no '
            'longer available; reauthentication is required.',
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

    // Firebase's first auth-state event is emitted after native persisted
    // credentials have been initialized. Unlike filtering for a non-null
    // event, this does not turn a legitimate signed-out state into a long
    // timeout before the Google fallback is considered.
    final restoredUser = await _auth.authStateChanges().first.timeout(
      timeout,
      onTimeout: () => currentUser,
    );
    return restoredUser ?? currentUser;
  }

  Future<User?> _restoreGoogleUser({
    String? expectedUid,
    String? expectedEmail,
  }) async {
    await _ensureGoogleInitialized();
    final restoration = _googleSignIn.attemptLightweightAuthentication(
      reportAllExceptions: true,
    );
    if (restoration == null) {
      throw const GoogleSessionConfirmationRequired(
        'lightweight authentication is unavailable',
      );
    }

    GoogleSignInAccount? googleUser;
    try {
      googleUser = await restoration.timeout(_googleRestoreTimeout);
    } catch (error) {
      throw GoogleSessionConfirmationRequired(error.toString());
    }
    if (googleUser == null) {
      throw const GoogleSessionConfirmationRequired(
        'no unambiguous saved Google account was returned',
      );
    }

    if (!_matchesSavedEmail(googleUser.email, expectedEmail)) {
      await _googleSignIn.signOut();
      throw const GoogleSessionConfirmationRequired(
        'the lightweight account did not match the saved account',
      );
    }

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw const GoogleSessionConfirmationRequired(
        'Google did not return an ID token',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final restoredUser = (await _auth.signInWithCredential(credential)).user;
    if (restoredUser == null ||
        (expectedUid != null &&
            expectedUid.isNotEmpty &&
            restoredUser.uid != expectedUid)) {
      await _auth.signOut();
      throw const GoogleSessionConfirmationRequired(
        'the restored Firebase account did not match the saved account',
      );
    }
    return restoredUser;
  }

  Future<User> confirmSavedGoogleSession() async {
    final preferences = await SharedPreferences.getInstance();
    final expectedUid = preferences.getString(_sessionUidKey);
    final expectedEmail = preferences.getString(_sessionEmailKey);

    await _ensureGoogleInitialized();
    final googleUser = await _googleSignIn.authenticate();
    if (!_matchesSavedEmail(googleUser.email, expectedEmail)) {
      await _googleSignIn.signOut();
      throw SavedGoogleAccountMismatch(expectedEmail: expectedEmail);
    }

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google did not return an ID token.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final firebaseUser = (await _auth.signInWithCredential(credential)).user;
    if (firebaseUser == null ||
        (expectedUid != null &&
            expectedUid.isNotEmpty &&
            firebaseUser.uid != expectedUid)) {
      await _auth.signOut();
      throw SavedGoogleAccountMismatch(expectedEmail: expectedEmail);
    }

    await _rememberAuthenticatedSession(provider: 'google');
    return firebaseUser;
  }

  bool _matchesSavedEmail(String actual, String? expected) {
    if (expected == null || expected.trim().isEmpty) return true;
    return actual.trim().toLowerCase() == expected.trim().toLowerCase();
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
    final user = currentUser;
    if (user != null) {
      await preferences.setString(_sessionUidKey, user.uid);
      final email = user.email?.trim();
      if (email != null && email.isNotEmpty) {
        await preferences.setString(_sessionEmailKey, email.toLowerCase());
      }
    }
  }

  Future<void> _clearSessionHints(SharedPreferences preferences) async {
    await preferences.remove(_sessionHintKey);
    await preferences.remove(_sessionProviderKey);
    await preferences.remove(_sessionUidKey);
    await preferences.remove(_sessionEmailKey);
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
  googleConfirmationRequired,
  retryableFailure,
}

class SessionRestoreResult {
  final SessionRestoreStatus status;
  final User? user;
  final Object? error;
  final String? expectedEmail;

  const SessionRestoreResult._(
    this.status, {
    this.user,
    this.error,
    this.expectedEmail,
  });

  const SessionRestoreResult.signedOut()
    : this._(SessionRestoreStatus.signedOut);

  const SessionRestoreResult.reauthenticationRequired()
    : this._(SessionRestoreStatus.reauthenticationRequired);

  factory SessionRestoreResult.authenticated(User user) =>
      SessionRestoreResult._(SessionRestoreStatus.authenticated, user: user);

  factory SessionRestoreResult.googleConfirmationRequired({
    String? expectedEmail,
  }) => SessionRestoreResult._(
    SessionRestoreStatus.googleConfirmationRequired,
    expectedEmail: expectedEmail,
  );

  factory SessionRestoreResult.retryableFailure([Object? error]) =>
      SessionRestoreResult._(
        SessionRestoreStatus.retryableFailure,
        error: error,
      );

  bool get isAuthenticated => status == SessionRestoreStatus.authenticated;
  bool get requiresReauthentication =>
      status == SessionRestoreStatus.reauthenticationRequired;
  bool get requiresGoogleConfirmation =>
      status == SessionRestoreStatus.googleConfirmationRequired;
  bool get shouldRetry => status == SessionRestoreStatus.retryableFailure;
}

class GoogleSessionConfirmationRequired implements Exception {
  final String reason;

  const GoogleSessionConfirmationRequired(this.reason);
}

class SavedGoogleAccountMismatch implements Exception {
  final String? expectedEmail;

  const SavedGoogleAccountMismatch({this.expectedEmail});
}
