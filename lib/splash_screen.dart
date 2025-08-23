import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'booking_page.dart'; // For Faculty
import 'admin_dashboard.dart'; // Manager home page
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();

    final isFacultyLoggedIn = prefs.getBool('isFacultyLoggedIn') ?? false;
    final isManagerLoggedIn = prefs.getBool('loggedIn') ?? false; // 🔥 Use 'loggedIn' key

    if (isFacultyLoggedIn) {
      final email = prefs.getString('facultyEmail') ?? '';
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingPage(facultyEmail: email),
        ),
      );
    } else if (isManagerLoggedIn) {
      // No email stored for manager, go directly
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminDashboardPage(), // 🔁 Replace if needed
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
