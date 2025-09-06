import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ViewHistoryPage extends StatefulWidget {
  const ViewHistoryPage({super.key});

  @override
  State<ViewHistoryPage> createState() => _ViewHistoryPageState();
}

class _ViewHistoryPageState extends State<ViewHistoryPage> {
  final _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all';

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
      debugPrint('Email API Response Body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext inContext) {
    final bookingsRef = _firestore
        .collection('new_bookings')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Booking History',
          style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[800],
        actions: [
          _buildFilterMenu(),
        ],
      ),
      backgroundColor: Colors.blue.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: bookingsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allBookings = snapshot.data!.docs;
          final filteredBookings = _filterBookings(allBookings);

          if (filteredBookings.isEmpty) {
            return Center(child: Text('No bookings found for the selected filter.', style: GoogleFonts.lato()));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    return _buildBookingCard(filteredBookings[index]);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<DocumentSnapshot> _filterBookings(List<DocumentSnapshot> bookings) {
    return bookings.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final pickupStatus = (data['pickup_status'] ?? '').toLowerCase();
      final dropStatus = (data['drop_status'] ?? '').toLowerCase();
      final pickupTripStatus = (data['pickupTripStatus'] ?? '').toLowerCase();
      final dropTripStatus = (data['dropTripStatus'] ?? '').toLowerCase();
      final selectedFilterLower = _selectedFilter.toLowerCase();
      
      final currentPickupStatus = _getStatus(data, 'pickup').toLowerCase();
      final currentDropStatus = _getStatus(data, 'drop').toLowerCase();

      // The 'all' filter shows any booking that is not in a 'pending' status.
      if (selectedFilterLower == 'all') {
        return (pickupStatus != 'pending' && pickupStatus.isNotEmpty) || (dropStatus != 'pending' && dropStatus.isNotEmpty);
      }
      
      // All other filters check against the determined current status for both trips.
      return currentPickupStatus == selectedFilterLower || currentDropStatus == selectedFilterLower;

    }).toList();
  }

  Widget _buildFilterMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list, color: Colors.white),
      onSelected: (String result) {
        setState(() {
          _selectedFilter = result;
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'all',
          child: Text('Show All'),
        ),
        const PopupMenuItem<String>(
          value: 'accepted',
          child: Text('Accepted'),
        ),
        const PopupMenuItem<String>(
          value: 'started',
          child: Text('Started'),
        ),
        const PopupMenuItem<String>(
          value: 'rejected',
          child: Text('Rejected'),
        ),
        const PopupMenuItem<String>(
          value: 'cancelled',
          child: Text('Cancelled'),
        ),
        const PopupMenuItem<String>(
          value: 'completed',
          child: Text('Completed'),
        ),
      ],
    );
  }

  void _cancelBooking(DocumentSnapshot doc, String type) async {
    final data = doc.data() as Map<String, dynamic>;
    final docRef = doc.reference;
    final String statusField = type == 'pickup' ? 'pickup_status' : 'drop_status';
    final String bookingId = doc.id;
    final String eventName = data['eventName'] ?? 'N/A';
    final String facultyEmail = data['facultyEmail'] ?? '';
    final String? driverId = data['${type}_driverId'];
    
    String driverPhone = '';

    try {
      if (driverId != null && driverId.isNotEmpty) {
        final driverDoc = await _firestore.collection('new_drivers').doc(driverId).get();
        if (driverDoc.exists) {
          driverPhone = driverDoc.data()?['phone'] ?? '';
          debugPrint('Fetched driver phone number: $driverPhone');
        } else {
          debugPrint('Driver document not found for ID: $driverId');
        }
      } else {
        debugPrint('Driver ID is missing. Cannot fetch phone number.');
      }

      await _firestore.runTransaction((transaction) async {
        try {
          final bookingDoc = await transaction.get(docRef);
          if (!bookingDoc.exists) {
            throw Exception("Booking document does not exist.");
          }
          final bookingData = bookingDoc.data() as Map<String, dynamic>;

          final currentStatus = (bookingData[statusField] ?? '').toLowerCase();
          if (currentStatus != 'accepted') {
            throw Exception("Booking is not in 'accepted' state and cannot be cancelled.");
          }

          final vehicleId = data['${type}_vehicleId'] ?? '';
          DocumentSnapshot? vehicleDoc;
          if (vehicleId.isNotEmpty) {
            final vehicleRef = _firestore.collection('new_vehicles').doc(vehicleId);
            vehicleDoc = await transaction.get(vehicleRef);
          }

          final driverDocInsideTransaction = driverId != null && driverId.isNotEmpty
              ? await transaction.get(_firestore.collection('new_drivers').doc(driverId))
              : null;


          // Update the booking status in the new_bookings collection
          transaction.update(docRef, {statusField: 'cancelled'});

          // Update the vehicle's booking list
          if (vehicleDoc != null && vehicleDoc.exists) {
            final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
            List bookings = vehicleData[type == 'pickup' ? 'pickup_bookings' : 'drop_bookings'] ?? [];
            final updatedBookings = bookings.where((booking) => booking['bookingId'] != bookingId).toList();
            transaction.update(vehicleDoc.reference, {
              type == 'pickup' ? 'pickup_bookings' : 'drop_bookings': updatedBookings
            });
          }

          // Update the driver's booking list
          if (driverDocInsideTransaction != null && driverDocInsideTransaction.exists) {
            final driverData = driverDocInsideTransaction.data() as Map<String, dynamic>;
            List driverBookings = driverData[type == 'pickup' ? 'pickup_bookings' : 'drop_bookings'] ?? [];
            final updatedDriverBookings = driverBookings.where((booking) => booking['bookingId'] != bookingId).toList();
            transaction.update(driverDocInsideTransaction.reference, {
              type == 'pickup' ? 'pickup_bookings' : 'drop_bookings': updatedDriverBookings
            });
          }
        } catch (e, stackTrace) {
          debugPrint('Error inside transaction: $e');
          debugPrint('Stack trace inside transaction: $stackTrace');
          rethrow;
        }
      });

      if (facultyEmail.isNotEmpty) {
        final subject = 'Apology for Booking Cancellation';
        final body = 'Dear Faculty,\n\nWe sincerely apologize, but your $type trip for the event "$eventName" has been cancelled due to unforeseen circumstances. We are sorry for that.\n\nThank you for your understanding.';
        _sendEmailViaBackend(to: facultyEmail, subject: subject, body: body);
      }
      debugPrint('Faculty email sent to $facultyEmail');

      if (driverPhone.isNotEmpty) {
        final message = 'We sincerely apologize, but the booking for event: $eventName on ${type == 'pickup' ? data['pickupDate'] : data['dropDate']} has been cancelled due to unforeseen circumstances. Please check the system for updates.';
        _launchWhatsApp(driverPhone, message);
      }
      debugPrint('Driver WhatsApp message sent to $driverPhone');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Your $type booking has been cancelled and notifications have been sent.')),
        );
      }
    } catch (e) {
      debugPrint('Error during cancellation transaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel the booking. Please try again.')),
        );
      }
    }
  }

  String _getStatus(Map<String, dynamic> data, String type) {
    final tripStatusField = type == 'pickup' ? 'pickupTripStatus' : 'dropTripStatus';
    final generalStatusField = type == 'pickup' ? 'pickup_status' : 'drop_status';

    // Check for the completed/cancelled status first
    if (data.containsKey(tripStatusField) && data[tripStatusField] != null && data[tripStatusField].isNotEmpty) {
      return data[tripStatusField] ?? 'N/A';
    }

    // Check if the trip has started
    if ((data['tripType'] == 'Round Trip' || type == 'pickup') && data[generalStatusField] == 'accepted') {
      final dateTimeString = '${data[type == 'pickup' ? 'pickupDate' : 'dropDate']} ${data[type == 'pickup' ? 'pickupTime' : 'dropTime']}';
      if (_isTripStarted(dateTimeString)) {
        return 'Started';
      }
    }

    // Default to the general status field
    return data[generalStatusField] ?? 'N/A';
  }

  bool _isTripStarted(String dateTimeString) {
    try {
      final format = DateFormat('d/M/yyyy h:mm a');
      final bookingDateTime = format.parse(dateTimeString);
      return DateTime.now().isAfter(bookingDateTime);
    } catch (e) {
      debugPrint('Error parsing date for trip started check: $e');
      return false;
    }
  }

  Widget _buildBookingCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final tripType = data['tripType'] ?? 'Single Trip';
    final isRoundTrip = tripType.toLowerCase() == 'round trip';

    // Pickup details
    final pickupDateTimeString = '${data['pickupDate']} ${data['pickupTime']}';
    final pickupStatus = _getStatus(data, 'pickup');
    final isPickupCancelable = _isFutureBooking(pickupDateTimeString) && pickupStatus == 'accepted';

    // Drop details
    final dropDateTimeString = isRoundTrip ? '${data['dropDate']} ${data['dropTime']}' : '';
    final dropStatus = isRoundTrip ? _getStatus(data, 'drop') : '';
    final isDropCancelable = isRoundTrip && _isFutureBooking(dropDateTimeString) && dropStatus == 'accepted';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tripType,
                  style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),

            Text('Pickup Details', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildStatusBadge(pickupStatus),
            _infoRow(Icons.event, 'Event:', data['eventName']),
            _infoRow(Icons.person, 'Resource Person:', data['resourcePerson']),
            _infoRow(Icons.directions_car, 'Facility:', data['facility']),
            _infoRow(Icons.calendar_today, 'Date:', data['pickupDate']),
            _infoRow(Icons.access_time, 'Time:', data['pickupTime']),
            _infoRow(Icons.location_on, 'From:', data['pickupFrom']),
            _infoRow(Icons.place, 'To:', data['pickupTo']),
            if (pickupStatus == 'rejected' && data['rejectionReason'] != null)
              _infoRow(Icons.info, 'Reason:', data['rejectionReason'], color: Colors.red),

            if (isRoundTrip) ...[
              const Divider(height: 20, thickness: 1),
              Text('Drop Details', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildStatusBadge(dropStatus),
              _infoRow(Icons.calendar_today, 'Date:', data['dropDate']),
              _infoRow(Icons.access_time, 'Time:', data['dropTime']),
              _infoRow(Icons.location_on, 'From:', data['dropFrom']),
              _infoRow(Icons.place, 'To:', data['dropTo']),
              if (dropStatus == 'rejected' && data['dropRejectionReason'] != null)
                _infoRow(Icons.info, 'Reason:', data['dropRejectionReason'], color: Colors.red),
            ],

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booked on: ${_formatTimestamp(data['timestamp'])}',
                  style: GoogleFonts.openSans(fontSize: 12, color: Colors.grey[600]),
                ),
                if (isPickupCancelable || isDropCancelable)
                  PopupMenuButton<String>(
                    onSelected: (String result) {
                      if (result == 'pickup') {
                        _showCancelDialog(context, doc, 'pickup');
                      } else if (result == 'drop') {
                        _showCancelDialog(context, doc, 'drop');
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return <PopupMenuEntry<String>>[
                        if (isPickupCancelable)
                          const PopupMenuItem<String>(
                            value: 'pickup',
                            child: Text('Cancel Pickup'),
                          ),
                        if (isDropCancelable)
                          const PopupMenuItem<String>(
                            value: 'drop',
                            child: Text('Cancel Drop'),
                          ),
                      ];
                    },
                    child: Text('Cancel', style: GoogleFonts.lato(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.lato(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, DocumentSnapshot doc, String type) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Cancellation'),
          content: Text('Are you sure you want to cancel this $type trip?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                _cancelBooking(doc, type);
                Navigator.of(context).pop();
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  bool _isFutureBooking(String bookingDateTimeString) {
    try {
      final format = DateFormat('d/M/yyyy h:mm a');
      final bookingDateTime = format.parse(bookingDateTimeString);
      return bookingDateTime.isAfter(DateTime.now());
    } catch (e) {
      debugPrint('Error parsing date for cancellation check: $e');
      return false;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.grey;
      case 'started':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      default:
        return Colors.black;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'pending':
        return Icons.schedule;
      case 'cancelled':
        return Icons.remove_circle_outline;
      case 'started':
        return Icons.play_circle_outline;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.info_outline;
    }
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: '$label ',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.normal,
                      color: Colors.black87,
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

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy @ hh:mm a').format(date);
  }
}