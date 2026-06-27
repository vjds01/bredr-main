import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

import 'user_session_service.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DatabaseEvent>? _connectionSubscription;
  bool _started = false;
  bool _showActivityStatus = true;

  Future<void> start() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null || _started) return;

    _started = true;
    WidgetsBinding.instance.addObserver(this);

    final profile =
        await _firestore.collection('users').doc(user.uid).get();
    _showActivityStatus =
        profile.data()?['showActivityStatus'] as bool? ?? true;

    _connectionSubscription = _database
        .ref('.info/connected')
        .onValue
        .listen((event) async {
      if (event.snapshot.value != true) return;
      await _configureConnection();
    }, onError: (_) {});
  }

  Future<void> stop() async {
    if (!_started) return;
    await setOffline();
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  Future<void> updateActivityVisibility(bool enabled) async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    _showActivityStatus = enabled;
    await _firestore.collection('users').doc(user.uid).set(
      {
        'showActivityStatus': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (enabled) {
      await setOnline();
    } else {
      await setOffline();
    }
  }

  Stream<DatabaseEvent> watchPresence(String userId) {
    return _database.ref('presence/$userId').onValue;
  }

  Future<void> _configureConnection() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    final reference = _database.ref('presence/${user.uid}');
    await reference.onDisconnect().set({
      'state': 'offline',
      'visible': _showActivityStatus,
      'lastChanged': ServerValue.timestamp,
    });

    if (_showActivityStatus) {
      await setOnline();
    } else {
      await setOffline();
    }
  }

  Future<void> setOnline() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null || !_showActivityStatus) return;

    await _database.ref('presence/${user.uid}').set({
      'state': 'online',
      'visible': true,
      'lastChanged': ServerValue.timestamp,
    });
  }

  Future<void> setOffline() async {
    final user = UserSessionService.instance.currentUser;
    if (user == null) return;

    await _database.ref('presence/${user.uid}').set({
      'state': 'offline',
      'visible': _showActivityStatus,
      'lastChanged': ServerValue.timestamp,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setOnline();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      setOffline();
    }
  }
}
