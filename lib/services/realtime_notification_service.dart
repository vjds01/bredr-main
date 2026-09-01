import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pendingNotificationTapKey = 'pending_local_notification_tap';

@pragma('vm:entry-point')
Future<void> breedrNotificationTapBackground(
  NotificationResponse response,
) async {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_pendingNotificationTapKey, payload);
}

class RealtimeNotificationService {
  RealtimeNotificationService._();

  static final RealtimeNotificationService instance =
      RealtimeNotificationService._();

  static const _channelId = 'breedr_realtime_updates';
  static const _channelName = 'Breedr updates';
  static const _channelDescription =
      'Messages, matches, adoption updates, and account alerts.';
  static const MethodChannel _androidTapChannel = MethodChannel(
    'breedr/notification_tap',
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<String?> tappedNotificationId = ValueNotifier<String?>(
    null,
  );

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _preferenceSubscription;
  Map<String, dynamic> _preferences = const <String, dynamic>{};
  final Set<String> _knownNotificationIds = <String>{};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _latestDocuments = const [];
  String? _activeUserId;
  bool _initialized = false;
  bool _receivedInitialSnapshot = false;

  bool get _supportsLocalNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized || !_supportsLocalNotifications) return;
    _initialized = true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      _androidTapChannel.setMethodCallHandler((call) async {
        if (call.method != 'notificationTapped') return;
        final payload = call.arguments?.toString();
        if (payload == null || payload.isEmpty) return;
        await _publishTap(payload);
      });
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          breedrNotificationTapBackground,
    );

    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      await _publishTap(launchPayload);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final nativePayload = await _androidTapChannel.invokeMethod<String>(
        'getInitialNotificationPayload',
      );
      if (nativePayload != null && nativePayload.isNotEmpty) {
        await _publishTap(nativePayload);
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
    }
  }

  Future<void> startForUser(String userId) async {
    if (userId.isEmpty) return;
    if (_activeUserId == userId && _notificationSubscription != null) return;
    final pendingTap = tappedNotificationId.value;
    await stop();
    _activeUserId = userId;
    _receivedInitialSnapshot = false;
    _knownNotificationIds.clear();

    await initialize();
    if (pendingTap != null && pendingTap.isNotEmpty) {
      await _publishTap(pendingTap);
    } else {
      await _recoverPendingTap();
    }
    await _requestPermission();

    _preferenceSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
          _preferences = Map<String, dynamic>.from(
            snapshot.data()?['notificationPreferences'] as Map? ??
                const <String, dynamic>{},
          );
          _updateUnreadCount();
        });

    _notificationSubscription = _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .listen(
          _handleSnapshot,
          onError: (Object error) {
            debugPrint('Realtime notification listener failed: $error');
          },
        );
  }

  Future<void> stop() async {
    await _notificationSubscription?.cancel();
    await _preferenceSubscription?.cancel();
    _notificationSubscription = null;
    _preferenceSubscription = null;
    _activeUserId = null;
    _receivedInitialSnapshot = false;
    _knownNotificationIds.clear();
    _latestDocuments = const [];
    _preferences = const <String, dynamic>{};
    unreadCount.value = 0;
    tappedNotificationId.value = null;
    final localPreferences = await SharedPreferences.getInstance();
    await localPreferences.remove(_pendingNotificationTapKey);
  }

  String? consumeTappedNotificationId() {
    final value = tappedNotificationId.value;
    tappedNotificationId.value = null;
    return value;
  }

  void _handleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _latestDocuments = snapshot.docs;
    _updateUnreadCount();

    if (!_receivedInitialSnapshot) {
      _knownNotificationIds.addAll(
        snapshot.docs.map((document) => document.id),
      );
      _receivedInitialSnapshot = true;
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final document = change.doc;
      if (!_knownNotificationIds.add(document.id)) continue;
      final data = document.data();
      if (data == null) continue;
      if (data['isRead'] == true || !_isEnabled(data)) continue;
      unawaited(_show(document.id, data));
    }
  }

  void _updateUnreadCount() {
    final visibleUnread = _latestDocuments.where((document) {
      final data = document.data();
      return data['isRead'] != true && _isEnabled(data);
    }).length;
    unreadCount.value = visibleUnread;
  }

  bool _isEnabled(Map<String, dynamic> data) {
    final preferenceKey = notificationPreferenceKeyForType(
      data['type']?.toString() ?? '',
    );
    if (preferenceKey == null) return true;
    return _preferences[preferenceKey] as bool? ?? true;
  }

  Future<void> _show(String documentId, Map<String, dynamic> data) async {
    if (!_supportsLocalNotifications) return;
    final title = _notificationTitle(data);
    final body = _text(data['message'], 'You have a new notification.');
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.social,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _localNotifications.show(
      id: documentId.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: details,
      payload: documentId,
    );
  }

  Future<void> _requestPermission() async {
    if (!_supportsLocalNotifications) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return;
    }
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    await _publishTap(payload);
  }

  Future<void> _publishTap(String payload) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingNotificationTapKey, payload);
    tappedNotificationId.value = payload;
  }

  Future<void> _recoverPendingTap() async {
    final preferences = await SharedPreferences.getInstance();
    final payload = preferences.getString(_pendingNotificationTapKey);
    if (payload == null || payload.isEmpty) return;
    tappedNotificationId.value = payload;
  }

  Future<void> clearPendingTap() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingNotificationTapKey);
  }
}

String? notificationPreferenceKeyForType(String type) {
  if (type == 'breeding_like_received' ||
      type == 'breeding_match_created' ||
      type.startsWith('breeding_completion') ||
      type == 'breeding_completed' ||
      type == 'breeding_auto_completed' ||
      type == 'match_ended') {
    return 'breedingLikes';
  }
  if (type.startsWith('adoption_request')) return 'adoptionRequests';
  if (type == 'adoption_process_contract_started') return 'contractUpdates';
  if (type.startsWith('adoption_process') ||
      type == 'adoption_ready_to_complete' ||
      type.startsWith('adoption_update') ||
      type == 'adoption_return_requested' ||
      type == 'adoption_return_decision') {
    return 'adoptionUpdates';
  }
  if (type == 'new_message') return 'newMessages';
  if (type.startsWith('pet_health')) return 'petHealth';
  if (type.startsWith('review')) return 'reviewsReceived';
  return null;
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _notificationTitle(Map<String, dynamic> data) {
  final storedTitle = _text(data['title'], 'Breedr update');
  if (data['type']?.toString() != 'new_message') return storedTitle;
  final actor = _text(data['actorName'], 'Someone');
  final pet = _text(data['petName'], '');
  return pet.isEmpty
      ? '$actor sent you a message'
      : '$actor sent you a message about $pet';
}
