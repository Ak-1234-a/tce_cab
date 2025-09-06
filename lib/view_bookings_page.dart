import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewBookingsPage extends StatelessWidget {
  final String email;

  const ViewBookingsPage({super.key, required this.email});

  // Manager's email for notifications
  static const String managerEmail = 'Transport@gen.tce.edu';

  // Helper function to send email via backend
  static Future<bool> _sendEmailViaBackend({
    required String to,
    required String subject,
    required String body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.tceapps.in/api/send-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': to,
          'subject': subject,
          'body': body,
        }),
      );
      debugPrint('Email API Response Status Code: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  // Helper function to launch WhatsApp
  static Future<void> _launchWhatsApp(String phoneNumber, String message) async {
    try {
      final encodedMessage = Uri.encodeComponent(message);
      final webUrl = Uri.parse("https://wa.me/$phoneNumber?text=$encodedMessage");

      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        final intentUrl = Uri.parse("intent://send?phone=$phoneNumber&text=$encodedMessage#Intent;scheme=smsto;package=com.whatsapp;end");
        if (await canLaunchUrl(intentUrl)) {
          await launchUrl(intentUrl, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch WhatsApp on this platform.');
        }
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  // Helper function to check if a booking is in the future
  bool _isFutureBooking(String date, String time) {
    try {
      final format = DateFormat('d/M/yyyy h:mm a');
      final bookingDateTime = format.parse('$date $time');
      return DateTime.now().isBefore(bookingDateTime);
    } catch (e) {
      debugPrint('Error parsing date for cancellation check: $e');
      return false;
    }
  }

  // Function to handle booking cancellation
  void _cancelBooking(BuildContext context, DocumentSnapshot doc, String leg) async {
    final data = doc.data() as Map<String, dynamic>;
    final docRef = doc.reference;
    final String statusField = '${leg}_status';
    final String eventName = data['eventName'] ?? 'N/A';
    final String facultyEmail = data['facultyEmail'] ?? '';
    final String bookingId = doc.id;

    // Fetch driver phone number outside the transaction for notification purposes
    String? driverPhone = data['${leg}_driverPhone'];

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Step 1: READ ALL DOCUMENTS FIRST
        final bookingDoc = await transaction.get(docRef);
        if (!bookingDoc.exists) {
          throw Exception("Booking document does not exist.");
        }
        final bookingData = bookingDoc.data() as Map<String, dynamic>;

        if ((bookingData[statusField] ?? '').toLowerCase() != 'accepted') {
          throw Exception("Booking is not in 'accepted' state and cannot be cancelled.");
        }

        final vehicleId = data['${leg}_vehicleId'] ?? '';
        final driverId = data['${leg}_driverId'] ?? '';

        DocumentSnapshot? vehicleDoc;
        if (vehicleId.isNotEmpty) {
          vehicleDoc = await transaction.get(FirebaseFirestore.instance.collection('new_vehicles').doc(vehicleId));
        }

        DocumentSnapshot? driverDoc;
        if (driverId.isNotEmpty) {
          driverDoc = await transaction.get(FirebaseFirestore.instance.collection('new_drivers').doc(driverId));
        }

        // Step 2: PERFORM ALL WRITES
        
        // Update the main booking status
        transaction.update(docRef, {statusField: 'cancelled'});

        // Update the vehicle's booking list if the document exists
        if (vehicleDoc != null && vehicleDoc.exists) {
          List bookings = (vehicleDoc.data() as Map<String, dynamic>)['${leg}_bookings'] ?? [];
          final updatedBookings = bookings.where((booking) => booking['bookingId'] != bookingId).toList();
          transaction.update(vehicleDoc.reference, {'${leg}_bookings': updatedBookings});
        }

        // Update the driver's booking list if the document exists
        if (driverDoc != null && driverDoc.exists) {
          List driverBookings = (driverDoc.data() as Map<String, dynamic>)['${leg}_bookings'] ?? [];
          final updatedDriverBookings = driverBookings.where((booking) => booking['bookingId'] != bookingId).toList();
          transaction.update(driverDoc.reference, {'${leg}_bookings': updatedDriverBookings});
        }
      });

      // Send notifications outside the transaction
      final managerSubject = 'Booking Cancellation Notification';
      final managerBody = 'Dear Manager,\n\nA booking for the event "$eventName" requested by $facultyEmail has been cancelled.';
      _sendEmailViaBackend(to: managerEmail, subject: managerSubject, body: managerBody);
      debugPrint('Manager email sent to $managerEmail');

      final driverMessage = 'We sincerely apologize, but the booking for event: $eventName on ${data['${leg}Date']} has been cancelled due to unforeseen circumstances. Please check the system for updates.';
      if (driverPhone != null && driverPhone.isNotEmpty) {
        _launchWhatsApp(driverPhone, driverMessage);
      }
      debugPrint('Driver WhatsApp message sent to $driverPhone');


      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${leg.capitalize()} booking has been cancelled and a notification has been sent to the manager and driver.')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error during cancellation transaction: $e');
      debugPrint('Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel the booking. Please try again.')),
        );
      }
    }
  }

  void _showRejectionDialog(BuildContext context, String reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rejection Reason',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        content: Text(
          reason,
          style: GoogleFonts.roboto(color: Colors.black87),
        ),
        actions: [
          TextButton(
            child: Text(
              'Close',
              style: GoogleFonts.roboto(color: Colors.blue.shade800),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showDriverDetailsDialog(BuildContext context, String driverName, String driverPhone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Driver Details',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.person, 'Name', driverName),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.phone, 'Phone', driverPhone),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              'Close',
              style: GoogleFonts.roboto(color: Colors.blue.shade800),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: '$label: ',
                style: GoogleFonts.roboto(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.normal,
                      color: Colors.blue.shade800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String status) {
    Color statusColor;
    String statusText = status;

    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange.shade700;
        break;
      case 'rejected':
        statusColor = Colors.red.shade700;
        break;
      case 'completed':
        statusColor = Colors.green.shade700;
        break;
      case 'cancelled':
        statusColor = Colors.grey.shade700;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.green.shade700;
        break;
    }

    return Row(
      children: [
        const Icon(Icons.info_outline, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          'Status: ',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
        Text(
          statusText,
          style: GoogleFonts.roboto(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  void _showCancelConfirmationDialog(BuildContext context, DocumentSnapshot doc, String leg) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Cancellation'),
          content: Text('Are you sure you want to cancel this ${leg.capitalize()} trip?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () {
                _cancelBooking(context, doc, leg);
                Navigator.of(context).pop();
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBookingCard({
    required BuildContext context,
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
    required String tripType,
    required String leg, // 'pickup' or 'drop'
  }) {
    String status = data['${leg}_status'] ?? '';
    String rejectionReason = (data['${leg}RejectionReason'] ?? '').toString();
    String driverName = (data['${leg}_driverName'] ?? '').toString();
    String driverPhone = (data['${leg}_driverPhone'] ?? '').toString();

    bool isRoundTrip = tripType.toLowerCase() == 'round trip';
    String bookingDate = data['${leg}Date'] ?? '';
    String bookingTime = data['${leg}Time'] ?? '';

    // Condition to show the cancel button
    bool isCancelable = status.toLowerCase() == 'accepted' && _isFutureBooking(bookingDate, bookingTime);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRoundTrip ? '${leg.capitalize()} Booking' : 'Single Trip',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
            const Divider(height: 16),
            _buildDetailRow(Icons.event, 'Event Name', data['eventName']),
            _buildDetailRow(Icons.alt_route, 'Trip Type', data['tripType']),
            _buildDetailRow(Icons.person, 'Resource Person', data['resourcePerson']),
            _buildDetailRow(Icons.directions_car, 'Facility', data['facility']),
            _buildDetailRow(Icons.location_on, '${leg.capitalize()} From', data['${leg}From']),
            _buildDetailRow(Icons.location_on, '${leg.capitalize()} To', data['${leg}To']),
            _buildDetailRow(Icons.date_range, '${leg.capitalize()} Date', bookingDate),
            _buildDetailRow(Icons.access_time, '${leg.capitalize()} Time', bookingTime),
            _buildDetailRow(Icons.people, 'Number of Persons', data['numberOfPersons']),
            const SizedBox(height: 12),
            _buildStatusRow(status),
            const SizedBox(height: 8),
            if (status.toLowerCase() == 'pending')
              Text(
                'Wait for manager to approve',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (status.toLowerCase() == 'rejected' && rejectionReason.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _showRejectionDialog(context, rejectionReason),
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: Text(
                    'View Rejection Reason',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (status.toLowerCase() == 'accepted' && driverName.isNotEmpty && driverPhone.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _showDriverDetailsDialog(context, driverName, driverPhone),
                  icon: const Icon(Icons.drive_eta, color: Colors.white),
                  label: Text(
                    'View Driver Details',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (isCancelable)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showCancelConfirmationDialog(context, doc, leg),
                  child: Text(
                    'Cancel Booking',
                    style: GoogleFonts.roboto(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Bookings', style: GoogleFonts.roboto(color: Colors.white)),
        backgroundColor: Colors.blue.shade800,
      ),
      backgroundColor: Colors.blue.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('new_bookings')
            .where('facultyEmail', isEqualTo: email)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading bookings', style: GoogleFonts.roboto()),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text('No bookings found', style: GoogleFonts.roboto(fontSize: 18)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data()! as Map<String, dynamic>;
              final tripType = (data['tripType'] ?? '').toString();
              
              if (tripType.toLowerCase() == 'round trip') {
                return Column(
                  children: [
                    _buildBookingCard(
                      context: context,
                      doc: docs[i],
                      data: data,
                      tripType: tripType,
                      leg: 'pickup',
                    ),
                    _buildBookingCard(
                      context: context,
                      doc: docs[i],
                      data: data,
                      tripType: tripType,
                      leg: 'drop',
                    ),
                  ],
                );
              } else {
                return _buildBookingCard(
                  context: context,
                  doc: docs[i],
                  data: data,
                  tripType: tripType,
                  leg: 'pickup',
                );
              }
            },
          );
        },
      ),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}