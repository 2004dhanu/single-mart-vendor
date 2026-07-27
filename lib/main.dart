import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/session_service.dart';
import 'screens/auth_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin_dashboard_screen.dart';

@pragma('vm:entry-point')
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

const InitializationSettings initializationSettings =
    InitializationSettings(
  android: initializationSettingsAndroid,
);

await flutterLocalNotificationsPlugin.initialize(
  initializationSettings,
);

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
);

await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);
  // Initialize Firebase with safety catch so configuration gaps don't crash startup
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Setup foreground listeners
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  debugPrint(
      'Foreground message received: ${message.notification?.title}');

  if (message.notification != null) {
    flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
});

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification clicked! message: ${message.messageId}');
    });

    // Request notification permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    try {
  await Future.delayed(const Duration(seconds: 2));

  final token = await FirebaseMessaging.instance.getToken();

  debugPrint("=================================");
  debugPrint("FCM TOKEN: $token");
  debugPrint("=================================");

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    debugPrint("NEW FCM TOKEN: $newToken");
  });
} catch (e) {
  debugPrint("FCM TOKEN ERROR: $e");
}
  } catch (e) {
    debugPrint("Firebase Core/Messaging Initialization failed: $e");
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
