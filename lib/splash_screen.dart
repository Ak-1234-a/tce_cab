import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'booking_page.dart';
import 'admin_dashboard.dart';
import 'main.dart';
import 'driver_dashboard.dart'; // Import the DriverDashboardPage

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
    final isManagerLoggedIn = prefs.getBool('loggedIn') ?? false;
    // Check for the driver's login status
    final isDriverLoggedIn = prefs.getBool('driverLoggedIn') ?? false;

    if (isFacultyLoggedIn) {
      final email = prefs.getString('facultyEmail') ?? '';
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingPage(facultyEmail: email),
        ),
      );
    } else if (isManagerLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminDashboardPage(),
        ),
      );
    } else if (isDriverLoggedIn) {
      // If a driver is logged in, navigate to the DriverDashboardPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DriverDashboardPage(),
        ),
      );
    } else {
      // If no one is logged in, show the main LoginPage
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