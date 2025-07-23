import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'manage_requests_page.dart';
import 'view_history_page.dart';
import 'drivers_page.dart'; // <-- Import the Drivers Page
import 'report_schedule_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        backgroundColor: Colors.blue.shade50,
        appBar: AppBar(
          elevation: 4,
          backgroundColor: Colors.blue[800],
          title: Row(
            children: [
              Image.asset(
                'assets/TCE.png',
                height: 40,
              ),
              const SizedBox(width: 12),
              Text(
                'Admin Dashboard',
                style: GoogleFonts.roboto(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
            ),
            tabs: [
              Tab(text: 'Manage Requests'),
            ],
          ),
        ),
        drawer: Drawer(
          backgroundColor: Colors.white,
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue[800],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      backgroundImage: AssetImage('assets/TCE.png'),
                      radius: 30,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Admin Menu',
                        style: GoogleFonts.roboto(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(
                icon: Icons.history,
                label: 'View History',
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ViewHistoryPage(),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.directions_car,
                label: 'Drivers',
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriversPage(),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.directions_bus,
                label: 'Vehicles',
                onTap: () {
                  // No action for now
                },
              ),
              _buildDrawerItem(
                icon: Icons.bar_chart,
                label: 'Generate Report',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportSchedulePage(),
                    ),
                  );
                },
              ),
              const Divider(),
              _buildDrawerItem(
                icon: Icons.logout,
                label: 'Logout',
                onTap: () {
                  // Handle logout
                },
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ManageRequestsPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[800]),
      title: Text(
        label,
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
