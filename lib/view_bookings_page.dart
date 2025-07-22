import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ViewBookingsPage extends StatelessWidget {
  final String email;

  const ViewBookingsPage({super.key, required this.email});

  void _showRejectionDialog(BuildContext context, String reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rejection Reason',
          style: GoogleFonts.openSans(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        content: Text(
          reason,
          style: GoogleFonts.openSans(color: Colors.black87),
        ),
        actions: [
          TextButton(
            child: Text(
              'Close',
              style: GoogleFonts.openSans(color: Colors.blue.shade800),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
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
                style: GoogleFonts.openSans(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.openSans(
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
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange.shade700;
        break;
      case 'rejected':
        statusColor = Colors.red.shade700;
        break;
      default:
        statusColor = Colors.green.shade700;
    }

    return Row(
      children: [
        const Icon(Icons.info_outline, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          'Status: ',
          style: GoogleFonts.openSans(
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
        Text(
          status,
          style: GoogleFonts.openSans(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Bookings', style: GoogleFonts.openSans(color: Colors.white)),
        backgroundColor: Colors.blue.shade800,
      ),
      backgroundColor: Colors.blue.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('facultyEmail', isEqualTo: email)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading bookings', style: GoogleFonts.openSans()),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text('No bookings found', style: GoogleFonts.openSans(fontSize: 18)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data()! as Map<String, dynamic>;

              final status = (data['status'] ?? '').toString();
              final rejectionReason = (data['rejectionReason'] ?? '').toString();

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
                        data['eventName'] ?? 'No Event Name',
                        style: GoogleFonts.lobster(
                          fontSize: 22,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildDetailRow(Icons.person, 'Resource Person', data['resourcePerson'] ?? ''),
                      _buildDetailRow(Icons.forward, 'Forward Through', data['forwardThrough'] ?? ''),
                      _buildDetailRow(Icons.directions_car, 'Facility', data['facility'] ?? ''),
                      _buildDetailRow(Icons.location_on, 'Pickup Location', data['pickupLocation'] ?? ''),
                      _buildDetailRow(Icons.location_on, 'Drop Location', data['dropLocation'] ?? ''),
                      _buildDetailRow(Icons.date_range, 'Pickup Date', data['pickupDate'] ?? ''),
                      _buildDetailRow(Icons.access_time, 'Pickup Time', data['pickupTime'] ?? ''),
                      _buildDetailRow(Icons.date_range, 'Drop Date', data['dropDate'] ?? ''),
                      _buildDetailRow(Icons.access_time, 'Drop Time', data['dropTime'] ?? ''),
                      _buildDetailRow(Icons.people, 'Number of Persons', data['numberOfPersons'] ?? ''),

                      const SizedBox(height: 12),
                      _buildStatusRow(status),

                      if (status.toLowerCase() == 'pending') ...[
                        const SizedBox(height: 8),
                        Text(
                          'Wait for manager to approve',
                          style: GoogleFonts.openSans(
                            fontSize: 14,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      if (status.toLowerCase() == 'rejected' && rejectionReason.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () => _showRejectionDialog(context, rejectionReason),
                            icon: const Icon(Icons.cancel, color: Colors.white),
                            label: Text(
                              'View Rejection Reason',
                              style: GoogleFonts.openSans(
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
                      ],
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
}
