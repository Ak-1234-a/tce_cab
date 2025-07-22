// TODO Implement this library.import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


class ViewHistoryPage extends StatelessWidget {
  const ViewHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bookingsRef = FirebaseFirestore.instance
        .collection('bookings')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Booking History',
          style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[800],
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

          final bookings = snapshot.data!.docs;

          if (bookings.isEmpty) {
            return const Center(child: Text('No bookings found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final data = bookings[index].data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.event, 'Event:', data['eventName']),
                      _infoRow(Icons.person, 'Resource Person:', data['resourcePerson']),
                      _infoRow(Icons.people, 'Persons:', data['numberOfPersons']),
                      _infoRow(Icons.directions_car, 'Facility:', data['facility']),
                      _infoRow(Icons.email, 'Faculty Email:', data['facultyEmail']),
                      _infoRow(Icons.route, 'Forward Through:', data['forwardThrough']),
                      const Divider(),
                      _infoRow(Icons.location_on, 'Pickup:', '${data['pickupLocation']} (${data['pickupDate']} @ ${data['pickupTime']})'),
                      _infoRow(Icons.place, 'Drop:', '${data['dropLocation']} (${data['dropDate']} @ ${data['dropTime']})'),
                      const Divider(),
                      _infoRow(
                        data['status'] == 'rejected'
                            ? Icons.cancel
                            : Icons.check_circle,
                        'Status:',
                        data['status'].toString().toUpperCase(),
                        color: data['status'] == 'rejected' ? Colors.red : Colors.green,
                      ),
                      if (data['status'] == 'rejected')
                        _infoRow(Icons.info, 'Rejection Reason:', data['rejectionReason']),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          'Booked on: ${_formatTimestamp(data['timestamp'])}',
                          style: GoogleFonts.openSans(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
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
    return '${date.day}/${date.month}/${date.year} @ ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
