import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/loading_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/realtime_notification_service.dart';

// void main() {
//   runApp(const BreedrApp());
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await RealtimeNotificationService.instance.initialize();

  runApp(const BreedrApp());
}

class BreedrApp extends StatelessWidget {
  const BreedrApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Breedr',
      debugShowCheckedModeBanner: false,
      theme: _breedrTheme(),
      home: const LoadingScreen(),
    );
  }
}

ThemeData _breedrTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFE5062)),
    useMaterial3: true,
  );
  final bodyTheme = GoogleFonts.urbanistTextTheme(base.textTheme);
  final headerTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
  final textTheme = bodyTheme.copyWith(
    displayLarge: headerTheme.displayLarge,
    displayMedium: headerTheme.displayMedium,
    displaySmall: headerTheme.displaySmall,
    headlineLarge: headerTheme.headlineLarge,
    headlineMedium: headerTheme.headlineMedium,
    headlineSmall: headerTheme.headlineSmall,
    titleLarge: headerTheme.titleLarge,
    titleMedium: headerTheme.titleMedium,
    titleSmall: headerTheme.titleSmall,
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
      base.primaryTextTheme,
    ),
    appBarTheme: AppBarTheme(
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF111111),
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}
