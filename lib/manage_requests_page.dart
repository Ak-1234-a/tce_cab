import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class BookingActions {
  // UPDATED LOGIC: Now checks for both date and time conflicts.
  static Future<Map<String, dynamic>?> _hasConflict(List<dynamic> bookings, String newDate, String newTime) async {
    if (bookings.isEmpty) return null;

    final dateFormat = DateFormat('d/M/yyyy h:mm a');

    try {
      final newDateTime = dateFormat.parse('$newDate $newTime');
      const assumedTripDuration = Duration(hours: 5); // Adjust this based on your typical trip length

      for (var booking in bookings) {
        if (booking is Map<String, dynamic>) {
          if (booking['tripStatus'] == 'completed' || booking['tripStatus'] == 'cancelled') {
            continue;
          }

          final existingDate = booking['pickupDate'];
          final existingTime = booking['pickupTime'];

          if (existingDate == newDate) {
            final existingDateTime = dateFormat.parse('$existingDate $existingTime');

            // Check for any overlap between the two time windows.
            final existingTripStart = existingDateTime;
            final existingTripEnd = existingTripStart.add(assumedTripDuration);

            final newTripStart = newDateTime;
            final newTripEnd = newTripStart.add(assumedTripDuration);

            if (newTripStart.isBefore(existingTripEnd) && newTripEnd.isAfter(existingTripStart)) {
              final conflictingBookingDoc = await FirebaseFirestore.instance
                  .collection('new_bookings')
                  .doc(booking['bookingId'])
                  .get();
              return conflictingBookingDoc.data();
            }
          }
        }
      }
    } catch (e) {
      // Handle parsing errors
      debugPrint('Error parsing date/time: $e');
    }
    return null;
  }

  static Future<void> onAccept(BuildContext context, String id, Map<String, dynamic> data, String bookingType) async {
    final bookingDoc = await FirebaseFirestore.instance.collection('new_bookings').doc(id).get();
    final bookingData = bookingDoc.data();
    if (bookingData == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking not found.')),
        );
      }
      return;
    }

    final newDate = bookingData['${bookingType.toLowerCase()}Date'];
    final newTime = bookingData['${bookingType.toLowerCase()}Time'];
    final facility = bookingData['facility'];

    // --- First, check vehicles based on date and time conflicts ---
    final vehicleSnap = await FirebaseFirestore.instance
        .collection('new_vehicles')
        .where('name', isEqualTo: facility)
        .get();

    final availableVehicles = <DocumentSnapshot>[];
    Map<String, dynamic>? conflictingVehicleEvent;

    for (var doc in vehicleSnap.docs) {
      final vehicleData = doc.data() as Map<String, dynamic>;
      final bookings = (vehicleData['pickup_bookings'] ?? []) as List<dynamic>;
      final bookings2 = (vehicleData['drop_bookings'] ?? []) as List<dynamic>;

      // UPDATED: Passing both newDate and newTime
      conflictingVehicleEvent = await _hasConflict(bookings, newDate, newTime) ?? await _hasConflict(bookings2, newDate, newTime);

      if (conflictingVehicleEvent == null) {
        availableVehicles.add(doc);
      }
    }

    if (availableVehicles.isEmpty) {
      if (context.mounted) {
        _showConflictDialog(context, 'No vehicles available', conflictingVehicleEvent);
      }
      return;
    }

    // --- Next, check drivers based on date and time conflicts ---
    final driverSnap = await FirebaseFirestore.instance.collection('new_drivers').get();

    final availableDrivers = <DocumentSnapshot>[];
    Map<String, dynamic>? conflictingDriverEvent;

    for (var doc in driverSnap.docs) {
      final driverData = doc.data() as Map<String, dynamic>;
      final bookings = (driverData['pickup_bookings'] ?? []) as List<dynamic>;
      final bookings2 = (driverData['drop_bookings'] ?? []) as List<dynamic>;

      // UPDATED: Passing both newDate and newTime
      conflictingDriverEvent = await _hasConflict(bookings, newDate, newTime) ?? await _hasConflict(bookings2, newDate, newTime);

      if (conflictingDriverEvent == null) {
        availableDrivers.add(doc);
      }
    }

    if (availableDrivers.isEmpty) {
      if (context.mounted) {
        _showConflictDialog(context, 'No drivers available', conflictingDriverEvent);
      }
      return;
    }

    // --- Show Dialogs for Selection ---
    Map<String, dynamic>? selectedVehicle;
    selectedVehicle = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Select Vehicle', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: availableVehicles.map((v) {
              final vd = v.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text('${vd['name']} – ${vd['numberPlate']}'),
                  subtitle: Text(vd['brand'] ?? ''),
                  onTap: () => Navigator.of(context).pop({'id': v.id, 'data': vd}),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (selectedVehicle == null) return;
    final selectedVehicleId = selectedVehicle['id'] as String?;
    final vehicleData = selectedVehicle['data'] as Map<String, dynamic>?;

    Map<String, dynamic>? selectedDriver;
    selectedDriver = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Select Driver', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: availableDrivers.map((d) {
              final dd = d.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text(dd['name'] ?? ''),
                  subtitle: Text(dd['phone'] ?? ''),
                  onTap: () => Navigator.of(context).pop({'id': d.id, 'data': dd}),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (selectedDriver == null) return;
    final selectedDriverId = selectedDriver['id'] as String?;
    final driverData = selectedDriver['data'] as Map<String, dynamic>?;

    if (selectedVehicleId == null || vehicleData == null || selectedDriverId == null || driverData == null) return;

    // --- Update bookings in the specified format with all necessary details ---
    final newBookingObject = {
      'bookingId': id,
      'pickupDate': bookingData['pickupDate'],
      'pickupFrom': bookingData['pickupFrom'],
      'pickupTime': bookingData['pickupTime'],
      'pickupTo': bookingData['pickupTo'],
      'tripStatus': 'Pending',
      'vehicleId': selectedVehicleId,
      'driverId': selectedDriverId,
      'driverName': driverData['name'],
      'driverPhone': driverData['phone'],
      if (bookingData['tripType'] == 'Round Trip') ...{
        'dropDate': bookingData['dropDate'],
        'dropTime': bookingData['dropTime'],
        'dropFrom': bookingData['dropFrom'],
        'dropTo': bookingData['dropTo'],
      }
    };

    final batch = FirebaseFirestore.instance.batch();

    // 1. Update new_bookings document with the status, vehicleId, and driverId
    batch.update(FirebaseFirestore.instance.collection('new_bookings').doc(id), {
      '${bookingType.toLowerCase()}_status': 'accepted',
      '${bookingType.toLowerCase()}_driverId': selectedDriverId,
      '${bookingType.toLowerCase()}_vehicleId': selectedVehicleId,
    });

    // 2. Add the new booking object to the driver's bookings array
    if (bookingType == 'Pickup') {
      batch.update(FirebaseFirestore.instance.collection('new_drivers').doc(selectedDriverId), {
        'pickup_bookings': FieldValue.arrayUnion([newBookingObject])
      });
    } else {
      batch.update(FirebaseFirestore.instance.collection('new_drivers').doc(selectedDriverId), {
        'drop_bookings': FieldValue.arrayUnion([newBookingObject])
      });
    }

    // 3. Add the new booking object to the vehicle's bookings array
    if (bookingType == 'Pickup') {
      batch.update(FirebaseFirestore.instance.collection('new_vehicles').doc(selectedVehicleId), {
        'pickup_bookings': FieldValue.arrayUnion([newBookingObject])
      });
    } else {
      batch.update(FirebaseFirestore.instance.collection('new_vehicles').doc(selectedVehicleId), {
        'drop_bookings': FieldValue.arrayUnion([newBookingObject])
      });
    }

    await batch.commit();

    // Get faculty name from the database
    final facultyEmail = bookingData['facultyEmail'];
    String facultyName = 'Faculty';
    String facultyPhone = '';
    try {
      final facultySnap = await FirebaseFirestore.instance
          .collection('faculty_logins')
          .where('email', isEqualTo: facultyEmail)
          .limit(1)
          .get();
      if (facultySnap.docs.isNotEmpty) {
        facultyName = facultySnap.docs.first.data()['name'] ?? 'Faculty';
        facultyPhone = facultySnap.docs.first.data()['phone'] ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching faculty name: $e');
    }

    // --- Send notifications with updated location details ---
    final phoneRaw = driverData['phone']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
    final phoneNumber = '91$phoneRaw';
    final eventName = bookingData['eventName'];
    final tripDetails = bookingType == 'Pickup'
        ? 'Pickup: ${bookingData['pickupDate']} at ${bookingData['pickupTime']} from ${bookingData['pickupFrom']} to ${bookingData['pickupTo']}'
        : 'Drop: ${bookingData['dropDate']} at ${bookingData['dropTime']} from ${bookingData['dropFrom']} to ${bookingData['dropTo']}';

    if (phoneRaw.isNotEmpty) {
      final message = '''
Hello ${driverData['name'] ?? 'Driver'},

You have been assigned a new ${bookingType.toLowerCase()} booking:

Event: $eventName
$tripDetails
Vehicle: ${vehicleData['name']} – ${vehicleData['numberPlate']}

Faculty Details:
Name: $facultyName
Email: $facultyEmail
Phone: $facultyPhone

Please be prepared.

Regards,
TCE Manager
''';
      await _launchWhatsApp(phoneNumber, message);
    }

    final emailResultFaculty = await _sendEmailViaBackend(
      to: facultyEmail,
      subject: 'Booking Accepted: ${bookingType} for ${eventName}',
      body: '''
Dear Sir/Madam,

Your booking request titled "${eventName}" has been accepted.

$tripDetails

Driver: ${driverData['name']} (${driverData['phone']})
Vehicle: ${vehicleData['name']} – ${vehicleData['numberPlate']}

Regards,
TCE Manager
''',
    );

    if (!context.mounted) return;
    if (emailResultFaculty) {
      _showDialog(
        context,
        'Success',
        'Booking accepted. WhatsApp opened for driver and email sent to faculty.',
        onPrincipalEmailTap: () async {
          final principalEmailResult = await _sendEmailToPrincipal(bookingData, selectedDriverId, selectedVehicleId);
          if (!context.mounted) return;
          if (principalEmailResult) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email sent to Principal successfully!')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send email to Principal.')));
          }
        },
      );
    } else {
      _showDialog(
        context,
        'Partial Success',
        'Booking accepted. WhatsApp opened for driver but failed to send email to faculty.',
        onPrincipalEmailTap: () async {
          final principalEmailResult = await _sendEmailToPrincipal(bookingData, selectedDriverId, selectedVehicleId);
          if (!context.mounted) return;
          if (principalEmailResult) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email sent to Principal successfully!')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send email to Principal.')));
          }
        },
      );
    }
  }

  static Future<void> onReject(BuildContext context, String id, Map<String, dynamic> data, String bookingType) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Booking', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please enter the reason for rejection:', style: GoogleFonts.poppins()),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rejection reason is required')),
                );
                return;
              }
              Navigator.of(context).pop(text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    final updates = {
      '${bookingType.toLowerCase()}_status': 'rejected',
      // UPDATED LOGIC: Use the correct field for the rejection reason based on booking type.
      bookingType.toLowerCase() == 'pickup' ? 'rejectionReason' : 'dropRejectionReason': reason,
    };
    await FirebaseFirestore.instance.collection('new_bookings').doc(id).update(updates);

    final facultyEmail = data['facultyEmail'];
    final eventName = data['eventName'];
    final pickupDetails = 'Pickup: ${data['pickupDate']} at ${data['pickupTime']} from ${data['pickupFrom']}';
    final dropDetails = 'Drop: ${data['dropDate']} at ${data['dropTime']} to ${data['dropTo']}';
    final tripDetails = bookingType == 'Pickup' ? pickupDetails : dropDetails;

    final emailSent = await _sendEmailViaBackend(
      to: facultyEmail,
      subject: 'Booking Rejected: ${bookingType} for ${eventName}',
      body: '''
Dear Sir/Madam,

We regret to inform you that your booking request titled "${eventName}" has been rejected.

Reason: $reason

$tripDetails

If you have any questions, please contact the transport office.

Regards,
TCE Manager
''',
    );

    if (!context.mounted) return;
    if (emailSent) {
      _showDialog(
        context,
        'Booking Rejected',
        'The booking request has been rejected and an email was sent to the faculty.\n\nReason: $reason',
      );
    } else {
      _showDialog(
        context,
        'Booking Rejected',
        'The booking request has been rejected.\n\n⚠️ Failed to send email.\n\nReason: $reason',
      );
    }
  }

  static Future<bool> _sendEmailToPrincipal(Map<String, dynamic> bookingData, String vehicleId, String driverId) async {
    final principalEmail = 'principal@tce.edu';
    final eventName = bookingData['eventName'] ?? 'N/A';
    final facultyEmail = bookingData['facultyEmail'] ?? 'N/A';
    final tripType = bookingData['tripType'] ?? 'N/A';
    final pickupDate = bookingData['pickupDate'] ?? 'N/A';
    final pickupTime = bookingData['pickupTime'] ?? 'N/A';
    final pickupFrom = bookingData['pickupFrom'] ?? 'N/A';
    final pickupTo = bookingData['pickupTo'] ?? 'N/A';

    String driverName = 'N/A';
    String vehicleName = 'N/A';
    String vehicleNumberPlate = 'N/A';

    try {
      final driverDoc = await FirebaseFirestore.instance.collection('new_drivers').doc(driverId).get();
      final vehicleDoc = await FirebaseFirestore.instance.collection('new_vehicles').doc(vehicleId).get();
      if (driverDoc.exists) {
        driverName = driverDoc.data()?['name'] ?? 'N/A';
      }
      if (vehicleDoc.exists) {
        vehicleName = vehicleDoc.data()?['name'] ?? 'N/A';
        vehicleNumberPlate = vehicleDoc.data()?['numberPlate'] ?? 'N/A';
      }
    } catch (e) {
      debugPrint('Error fetching driver or vehicle data: $e');
    }

    final emailBody = '''
Dear Principal,

This is an automated notification to inform you that a new transport booking has been accepted.

Event Name: $eventName
Faculty Email: $facultyEmail
Trip Type: $tripType

Pickup Details:
Date: $pickupDate
Time: $pickupTime
From: $pickupFrom
To: $pickupTo

Driver: $driverName
Vehicle: $vehicleName ($vehicleNumberPlate)

Regards,
TCE Transport Management System
''';
    return _sendEmailViaBackend(
      to: principalEmail,
      subject: 'New Booking Accepted: $eventName',
      body: emailBody,
    );
  }

  static Future<void> _launchWhatsApp(String phoneNumber, String message) async {
    try {
      final encodedMessage = Uri.encodeComponent(message);
      final intentUrl = Uri.parse("intent://send?phone=$phoneNumber&text=$encodedMessage#Intent;scheme=smsto;package=com.whatsapp;end");
      if (await canLaunchUrl(intentUrl)) {
        await launchUrl(intentUrl, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse("https://wa.me/$phoneNumber?text=$encodedMessage");
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle exceptions
    }
  }

  static Future<bool> _sendEmailViaBackend({
    required String to,
    required String subject,
    required String body,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.tceapps.in/api/send-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'to': to,
        'subject': subject,
        'body': body,
      }),
    );
    return response.statusCode == 200;
  }

  static void _showDialog(BuildContext context, String title, String message, {VoidCallback? onPrincipalEmailTap}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          if (onPrincipalEmailTap != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the first dialog
                onPrincipalEmailTap();
              },
              child: const Text('Send Email to Principal'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  static void _showConflictDialog(BuildContext context, String title, Map<String, dynamic>? conflictData) {
    if (conflictData == null) {
      _showDialog(context, title, 'No more details available on the conflict.');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The resource is already booked for the following event:', style: GoogleFonts.poppins()),
            const SizedBox(height: 12),
            Text('Event: ${conflictData['eventName'] ?? 'N/A'}', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            Text('Date: ${conflictData['pickupDate'] ?? 'N/A'}', style: GoogleFonts.poppins()),
            Text('Time: ${conflictData['pickupTime'] ?? 'N/A'}', style: GoogleFonts.poppins()),
            Text('From: ${conflictData['pickupFrom'] ?? 'N/A'}', style: GoogleFonts.poppins()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }
}

class ManageRequestsPage extends StatefulWidget {
  const ManageRequestsPage({super.key});

  @override
  State<ManageRequestsPage> createState() => _ManageRequestsPageState();
}

class _ManageRequestsPageState extends State<ManageRequestsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('new_bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          final pickupRequests = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['pickup_status'] == 'Pending';
          }).toList();
          final dropRequests = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['tripType'] == 'Round Trip' && data['drop_status'] == 'Pending';
          }).toList();

          if (pickupRequests.isEmpty && dropRequests.isEmpty) {
            return Center(
              child: Text('No pending requests.', style: GoogleFonts.poppins(fontSize: 16)),
            );
          }

          final priorityOrder = ['principal@tce.edu', 'hodit@tce.edu', 'hodcse@tce.edu', 'deanacad@tce.edu'];
          pickupRequests.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            int ap = priorityOrder.indexWhere((e) => aData['facultyEmail']?.contains(e) ?? false);
            int bp = priorityOrder.indexWhere((e) => bData['facultyEmail']?.contains(e) ?? false);
            ap = ap == -1 ? 100 : ap;
            bp = bp == -1 ? 100 : bp;
            if (ap != bp) return ap.compareTo(bp);
            return (aData['timestamp'] as Timestamp).compareTo(bData['timestamp'] as Timestamp);
          });
          dropRequests.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            return (aData['timestamp'] as Timestamp).compareTo(bData['timestamp'] as Timestamp);
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pickupRequests.isNotEmpty) ...[
                  Text('Pending Pickup Requests',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                  const SizedBox(height: 16),
                  ...pickupRequests.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return BookingCardWrapper(
                      docId: doc.id,
                      data: data,
                      bookingType: 'Pickup',
                      onAccept: () => BookingActions.onAccept(context, doc.id, data, 'Pickup'),
                      onReject: () => BookingActions.onReject(context, doc.id, data, 'Pickup'),
                    );
                  }).toList(),
                ],
                if (dropRequests.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Text('Pending Drop Requests',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                  const SizedBox(height: 16),
                  ...dropRequests.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return BookingCardWrapper(
                      docId: doc.id,
                      data: data,
                      bookingType: 'Drop',
                      onAccept: () => BookingActions.onAccept(context, doc.id, data, 'Drop'),
                      onReject: () => BookingActions.onReject(context, doc.id, data, 'Drop'),
                    );
                  }).toList(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class BookingCardWrapper extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String bookingType;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const BookingCardWrapper({
    super.key,
    required this.docId,
    required this.data,
    required this.bookingType,
    required this.onAccept,
    required this.onReject,
  });

  Future<String> _getFacultyName(String email) async {
    final snap = await FirebaseFirestore.instance
        .collection('faculty_logins')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.first.data()['name'] ?? 'Unknown';
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getFacultyName(data['facultyEmail']),
      builder: (context, snapshot) {
        final name = snapshot.data ?? 'Loading...';
        return BookingCard(
          data: {...data, 'name': name},
          bookingType: bookingType,
          onAccept: onAccept,
          onReject: onReject,
        );
      },
    );
  }
}

class BookingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String bookingType;
  final VoidCallback onAccept, onReject;

  const BookingCard({
    super.key,
    required this.data,
    required this.bookingType,
    required this.onAccept,
    required this.onReject,
  });

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.black87), // Updated icon color
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: '$label ',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.normal, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    final pickupDate = data['pickupDate'] ?? '';
    final pickupTime = data['pickupTime'] ?? '';
    final pickupFrom = data['pickupFrom'] ?? '';
    final pickupTo = data['pickupTo'] ?? '';

    final dropDate = data['dropDate'] ?? '';
    final dropTime = data['dropTime'] ?? '';
    final dropFrom = data['dropFrom'] ?? '';
    final dropTo = data['dropTo'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade200],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${bookingType} Booking',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                    ),
                    Icon(
                      Icons.directions_bus,
                      color: Colors.blue.shade900,
                      size: 32,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _row(Icons.event, 'Event:', data['eventName'] ?? ''),
                _row(Icons.calendar_month, 'Date:', bookingType == 'Pickup' ? pickupDate : dropDate),
                _row(Icons.access_time, 'Time:', bookingType == 'Pickup' ? pickupTime : dropTime),
                const SizedBox(height: 12),
                if (data['tripType'] == 'Round Trip') ...[
                  _row(Icons.outbound, 'From:', pickupFrom),
                  _row(Icons.swap_horiz, 'To:', dropTo),
                ],
                if (data['tripType'] == 'Single Trip') ...[
                  _row(Icons.outbound, 'From:', pickupFrom),
                  _row(Icons.swap_horiz, 'To:', pickupTo),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.black26),
                const SizedBox(height: 12),
                _row(Icons.people, 'Persons:', '${data['numberOfPersons']}'),
                _row(Icons.directions_car, 'Facility:', data['facility'] ?? ''),
                _row(Icons.person, 'Resource:', data['resourcePerson'] ?? ''),
                _row(Icons.email, 'Requested by:', data['name'] ?? ''),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        label: Text('Accept',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        label: Text('Reject',
                            style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}