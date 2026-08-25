import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_session_service.dart';

class AppGuideService {
  AppGuideService._();

  static final AppGuideService instance = AppGuideService._();

  static const _mainGuideLocalKeyPrefix = 'main_guide_completed';

  Future<bool> hasCompletedMainGuide() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return true;

    final prefs = await SharedPreferences.getInstance();
    final localKey = _localKey(user.uid);
    if (prefs.getBool(localKey) == true) return true;

    try {
      final profile = await UserSessionService.instance.getCurrentUserProfile();
      final data = profile?.data();
      final role = data?['role']?.toString().trim().toLowerCase();
      if (role == 'admin') return true;

      final guideStatus = Map<String, dynamic>.from(
        data?['guideStatus'] as Map? ?? const <String, dynamic>{},
      );
      final completed = guideStatus['mainGuideCompleted'] as bool? ?? false;
      if (completed) {
        await prefs.setBool(localKey, true);
      }
      return completed;
    } catch (_) {
      return false;
    }
  }

  Future<void> markMainGuideCompleted() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localKey(user.uid), true);

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'guideStatus': {
        'mainGuideCompleted': true,
        'mainGuideCompletedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _localKey(String uid) => '${_mainGuideLocalKeyPrefix}_$uid';
}
