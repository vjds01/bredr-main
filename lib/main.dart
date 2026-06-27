import 'dart:async';

import 'package:flutter/material.dart';
import 'screens/loading_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/password_reset_link_service.dart';
import 'screens/auth/create_new_password_screen.dart';

// void main() {
//   runApp(const BreedrApp());
// } 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await PasswordResetLinkService.instance.initialize();

  runApp(const BreedrApp());
}

class BreedrApp extends StatelessWidget {
  const BreedrApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return _PasswordResetLinkListener(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Breedr',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFE5062)),
          fontFamily: 'sans-serif',
          useMaterial3: true,
        ),
        home: const LoadingScreen(),
      ),
    );
  }
}

class _PasswordResetLinkListener extends StatefulWidget {
  final Widget child;

  const _PasswordResetLinkListener({required this.child});

  @override
  State<_PasswordResetLinkListener> createState() =>
      _PasswordResetLinkListenerState();
}

class _PasswordResetLinkListenerState
    extends State<_PasswordResetLinkListener> {
  StreamSubscription<String>? _resetCodeSubscription;

  @override
  void initState() {
    super.initState();
    _resetCodeSubscription =
        PasswordResetLinkService.instance.resetCodes.listen(_openResetPassword);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingCode =
          PasswordResetLinkService.instance.consumePendingResetCode();
      if (pendingCode != null) _openResetPassword(pendingCode);
    });
  }

  @override
  void dispose() {
    _resetCodeSubscription?.cancel();
    super.dispose();
  }

  void _openResetPassword(String code) {
    final navigator = BreedrApp.navigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => CreateNewPasswordScreen(resetCode: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
