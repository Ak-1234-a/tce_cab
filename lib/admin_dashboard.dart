import 'package:flutter/material.dart';
import 'manage_requests_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});
  @override
  Widget build(BuildContext ctx) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Manage Requests'),
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
}
