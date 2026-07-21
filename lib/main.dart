import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/session_service.dart';
import 'screens/auth_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with safety catch so configuration gaps don't crash startup
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Core Initialization failed: $e");
  }

  final isLoggedIn = await SessionService.isLoggedIn();
  final isVerified = await SessionService.getVerificationStatus();
  
  final user = await SessionService.getUserDetails();
  final isAdmin = user != null && (user['user_type'] == 3 || user['user_position'] == 'Admin');

  runApp(MyApp(
    isLoggedIn: isLoggedIn,
    isVerified: isVerified,
    isAdmin: isAdmin,
  ));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final int isVerified;
  final bool isAdmin;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.isVerified,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    Widget initialHome;

    if (isLoggedIn) {
      if (isAdmin) {
        initialHome = const AdminDashboardScreen();
      } else if (isVerified == 1) {
        initialHome = const DashboardScreen();
      } else {
        initialHome = const PendingScreen();
      }
    } else {
      initialHome = const AuthScreen();
    }

    return MaterialApp(
      title: 'Single Mart Vendor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: initialHome,
    );
  }
}
