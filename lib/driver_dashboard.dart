import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart'; // For deep equality
import 'package:intl/intl.dart';

import 'driver_login_page.dart';

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  String? _driverPhone;
  String? _driverName;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _driverPhone = prefs.getString('driverPhone');
      _driverName = prefs.getString('driverName');
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('driverLoggedIn');
    await prefs.remove('driverName');
    await prefs.remove('driverPhone');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DriverLoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_driverPhone == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset(
              'assets/TCE.png',
              height: 32,
            ),
            const SizedBox(width: 10),
            const Text(
              'TCE Vehicle',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('new_drivers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs;
          if (docs == null || docs.isEmpty) {
            return const Center(child: Text('No data found.'));
          }

          List<dynamic> allPickupBookings = [];
          List<dynamic> allDropBookings = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            allPickupBookings.addAll(data['pickup_bookings'] ?? []);
            allDropBookings.addAll(data['drop_bookings'] ?? []);
          }

          final pickupBookings = allPickupBookings.where((booking) {
            return booking['driverPhone'] == _driverPhone;
          }).toList();

          final dropBookings = allDropBookings.where((booking) {
            return booking['driverPhone'] == _driverPhone;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(context, 'Pickup Bookings'),
                const SizedBox(height: 8),
                if (pickupBookings.isNotEmpty)
                  ...pickupBookings.map(
                        (b) => BookingCard(
                      booking: b,
                      type: BookingType.pickup,
                    ),
                  )
                else
                  _noBookingMessage('No pickup bookings found.'),
                const SizedBox(height: 24),
                _sectionTitle(context, 'Drop‑Off Bookings'),
                const SizedBox(height: 8),
                if (dropBookings.isNotEmpty)
                  ...dropBookings.map(
                        (b) => BookingCard(
                      booking: b,
                      type: BookingType.drop,
                    ),
                  )
                else
                  _noBookingMessage('No drop‑off bookings found.'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge!.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.green.shade700,
      ),
    );
  }

  Widget _noBookingMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.green.shade700),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: AssetImage('assets/TCE.png'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _driverName ?? 'Driver',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _driverPhone ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

enum BookingType { pickup, drop }

class BookingCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final BookingType type;

  const BookingCard({
    super.key,
    required this.booking,
    required this.type,
  });

  @override
  _BookingCardState createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  bool _isCompleted = false;
  String? vehicleName;
  String? vehicleNumberPlate;
  String? driverDocId;

  @override
  void initState() {
    super.initState();
    _fetchVehicleAndDriverDoc();
  }

  Future<void> _fetchVehicleAndDriverDoc() async {
    final vehicleId = widget.booking['vehicleId'];
    final driverPhone = widget.booking['driverPhone'];

    if (vehicleId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('new_vehicles')
          .doc(vehicleId)
          .get();

      if (doc.exists) {
        setState(() {
          vehicleName = doc['name'];
          vehicleNumberPlate = doc['numberPlate'];
        });
      }
    }

    final driverDocs = await FirebaseFirestore.instance
        .collection('new_drivers')
        .where('phone', isEqualTo: driverPhone)
        .get();

    if (driverDocs.docs.isNotEmpty) {
      setState(() {
        driverDocId = driverDocs.docs.first.id;
      });
    }
  }

  DateTime? _getBookingDateTime() {
    final isPickup = widget.type == BookingType.pickup;
    final dateStr = widget.booking[isPickup ? 'pickupDate' : 'dropDate'];
    final timeStr = widget.booking[isPickup ? 'pickupTime' : 'dropTime'];

    if (dateStr == null || timeStr == null) return null;

    try {
      final dateParts = dateStr.split('/');
      if (dateParts.length != 3) return null;

      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      final timeFormat =
      RegExp(r'(\d{1,2}):(\d{2})\s?(AM|PM)', caseSensitive: false);
      final match = timeFormat.firstMatch(timeStr);
      if (match == null) return null;

      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final ampm = match.group(3)!.toUpperCase();

      if (ampm == 'PM' && hour != 12) {
        hour += 12;
      } else if (ampm == 'AM' && hour == 12) {
        hour = 0;
      }

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  bool get _isCheckboxEnabled {
    final bookingDateTime = _getBookingDateTime();
    if (bookingDateTime == null) return false;

    final now = DateTime.now();
    return now.isAtSameMomentAs(bookingDateTime) || now.isAfter(bookingDateTime);
  }

  Future<void> _markAsCompleted() async {
    final booking = widget.booking;
    final type = widget.type;

    final vehicleId = booking['vehicleId'];
    final driverPhone = booking['driverPhone'];
    final bookingId = booking['bookingId'];
    const managerPhone = '7200306251';

    if (driverDocId == null ||
        vehicleId == null ||
        driverPhone == null ||
        bookingId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Missing required data')));
      return;
    }

    try {
      final key = type == BookingType.pickup ? 'pickup_bookings' : 'drop_bookings';

      // Remove from driver’s bookings
      final driverRef =
      FirebaseFirestore.instance.collection('new_drivers').doc(driverDocId);
      final driverSnap = await driverRef.get();
      final driverData = driverSnap.data();
      List<dynamic> driverBookings = List.from(driverData?[key] ?? []);
      driverBookings.removeWhere((b) =>
          const DeepCollectionEquality().equals(b, booking));
      await driverRef.update({key: driverBookings});

      // Remove from vehicle’s bookings
      final vehicleRef =
      FirebaseFirestore.instance.collection('new_vehicles').doc(vehicleId);
      final vehicleSnap = await vehicleRef.get();
      final vehicleData = vehicleSnap.data();
      List<dynamic> vehicleBookings = List.from(vehicleData?[key] ?? []);
      vehicleBookings.removeWhere((b) =>
          const DeepCollectionEquality().equals(b, booking));
      await vehicleRef.update({key: vehicleBookings});

      // Update status in new_bookings
      final bookingRef =
      FirebaseFirestore.instance.collection('new_bookings').doc(bookingId);
      final statusField =
      type == BookingType.pickup ? 'pickupTripStatus' : 'dropTripStatus';
      final bookingSnap = await bookingRef.get();
      final bookingData = bookingSnap.data() as Map<String, dynamic>;

      if (!bookingData.containsKey(statusField)) {
        await bookingRef.update({statusField: 'Completed'});
      }

      // Send WhatsApp notification
      final message = '''
✅ ${type == BookingType.pickup ? "Pickup" : "Drop‑Off"} Trip Completed
📅 Date: ${type == BookingType.pickup ? booking["pickupDate"] : booking["dropDate"]}
⏰ Time: ${type == BookingType.pickup ? booking["pickupTime"] : booking["dropTime"]}
Event : ${booking["eventName"] ?? 'N/A'}
From : ${booking["pickupFrom"] ?? booking["dropFrom"] ?? 'N/A'}
To : ${booking["pickupTo"] ?? booking["dropTo"] ?? 'N/A'}
📱 Driver: $driverPhone
''';

      
      try {
      final encodedMessage = Uri.encodeComponent(message);
      final intentUrl = Uri.parse("intent://send?phone=$managerPhone&text=$encodedMessage#Intent;scheme=smsto;package=com.whatsapp;end");
      if (await canLaunchUrl(intentUrl)) {
        await launchUrl(intentUrl, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse("https://wa.me/$managerPhone?text=$encodedMessage");
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle exceptions
    }

      setState(() {
        _isCompleted = true;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Marked as completed.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPickup = widget.type == BookingType.pickup;
    final title = isPickup ? 'Pickup Booking' : 'Drop‑Off Booking';
    final dateKey = isPickup ? 'pickupDate' : 'dropDate';
    final timeKey = isPickup ? 'pickupTime' : 'dropTime';
    final fromKey = isPickup ? 'pickupFrom' : 'dropFrom';
    final toKey = isPickup ? 'pickupTo' : 'dropTo';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade700, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _infoRow(Icons.calendar_today, 'Date', widget.booking[dateKey]),
                  _infoRow(Icons.access_time, 'Time', widget.booking[timeKey]),
                  _infoRow(Icons.location_on, 'From', widget.booking[fromKey]),
                  _infoRow(Icons.location_on_outlined, 'To', widget.booking[toKey]),
                  if (vehicleName != null && vehicleNumberPlate != null)
                    _infoRow(Icons.directions_car, 'Vehicle',
                        '$vehicleName, $vehicleNumberPlate'),
                ],
              ),
            ),
            Column(
              children: [
                Checkbox(
                  value: _isCompleted,
                  onChanged: (_isCompleted || !_isCheckboxEnabled)
                      ? null
                      : (val) async {
                    await _markAsCompleted();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value ?? '—',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
