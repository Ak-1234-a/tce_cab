import 'package:flutter/material.dart';
import 'faculty_login_page.dart';
import 'manager_login_page.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Initialize FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint("🔔 [Background] Message received: ${message.messageId}");
  debugPrint("🔔 [Background] Notification Title: ${message.notification?.title}");
  debugPrint("🔔 [Background] Notification Body: ${message.notification?.body}");
  debugPrint("🔔 [Background] Message Data: ${message.data}");

  // Show local notification manually for background messages
  if (message.notification != null) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'booking_notifications',
      'Booking Notifications',
      channelDescription: 'Channel for booking updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      message.messageId.hashCode,
      message.notification!.title,
      message.notification!.body,
      notificationDetails,
    );
  }
}

// Create notification channel for Android 8.0+ (Oreo+)
Future<void> _createNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'booking_notifications',
    'Booking Notifications',
    description: 'Channel for booking updates',
    importance: Importance.high,
  );

  final androidFlutterLocalNotificationsPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidFlutterLocalNotificationsPlugin?.createNotificationChannel(channel);
}

// Show notification for foreground messages
Future<void> _showFlutterNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'booking_notifications',
    'Booking Notifications',
    channelDescription: 'Channel for booking updates',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    message.messageId.hashCode,
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? '',
    notificationDetails,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Create notification channel before anything else
  await _createNotificationChannel();

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize flutter_local_notifications plugin
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    // Request permission for notifications (iOS mostly)
    final settings = await _firebaseMessaging.requestPermission();
    debugPrint("📋 Notification permission status: ${settings.authorizationStatus}");

    // Get the device token for FCM
    final token = await _firebaseMessaging.getToken();
    debugPrint("🔑 FCM Token: $token");

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📥 [Foreground] Message received:");
      debugPrint("📌 Title: ${message.notification?.title}");
      debugPrint("📌 Body: ${message.notification?.body}");
      debugPrint("📌 Data: ${message.data}");

      _showFlutterNotification(message);
    });

    // Listen for notification taps when app is in background or foreground
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("🔗 Notification tapped. Data: ${message.data}");
      // Add navigation logic if needed here
    });

    // Check if app was opened from a terminated state by a notification tap
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("🚀 App launched via notification tap: ${initialMessage.data}");
      // Navigate if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCE Vehicle Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage('assets/TCE.png'),
              ),
              const SizedBox(height: 24),
              Text(
                'TCE Vehicle Booking',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please mention Login as',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blueGrey,
                    ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManagerLoginPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Manager Login',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FacultyLoginPage(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue.shade700, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Faculty Login',
                    style:
                        TextStyle(fontSize: 16, color: Colors.blue.shade700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
