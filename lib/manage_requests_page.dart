import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageRequestsPage extends StatelessWidget {
  const ManageRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('status', isEqualTo: 'Pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No pending requests.',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          const List<String> priorityOrder = [
            'principal@tce.edu',
            'hod@tce.edu',
            'deanacad@tce.edu',
          ];

          docs.sort((a, b) {
            int aPriority = priorityOrder.indexWhere(
                (email) => a['facultyEmail'].toString().contains(email));
            int bPriority = priorityOrder.indexWhere(
                (email) => b['facultyEmail'].toString().contains(email));

            aPriority = aPriority == -1 ? 100 : aPriority;
            bPriority = bPriority == -1 ? 100 : bPriority;

            if (aPriority != bPriority) {
              return aPriority.compareTo(bPriority);
            }

            Timestamp at = a['timestamp'] ?? Timestamp(0, 0);
            Timestamp bt = b['timestamp'] ?? Timestamp(0, 0);
            return at.compareTo(bt);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: Colors.blue.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['eventName'] ?? 'Untitled Event',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _infoRow(Icons.calendar_month, 'Pickup:',
                            '${data['pickupDate']} at ${data['pickupTime']} from ${data['pickupLocation']}'),
                        const SizedBox(height: 6),
                        _infoRow(Icons.place, 'Drop:',
                            '${data['dropDate']} at ${data['dropTime']} to ${data['dropLocation']}'),
                        const SizedBox(height: 10),
                        _infoRow(Icons.people, 'Persons:',
                            '${data['numberOfPersons']}'),
                        _infoRow(Icons.school, 'Facility:',
                            data['facility'] ?? ''),
                        _infoRow(Icons.person, 'Resource Person:',
                            data['resourcePerson'] ?? ''),
                        _infoRow(Icons.forward, 'Forwarded Through:',
                            data['forwardThrough'] ?? ''),
                        _infoRow(Icons.email, 'Requested by:',
                            data['facultyEmail'] ?? ''),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () => _acceptRequest(context, doc.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                label: Text(
                                  'Accept',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.cancel_outlined,
                                    color: Colors.red),
                                onPressed: () =>
                                    _denyRequest(context, doc.id),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                label: Text(
                                  'Reject',
                                  style: GoogleFonts.poppins(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: '$label ',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _acceptRequest(BuildContext context, String docId) async {
    try {
      final driverSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('isFree', isEqualTo: true)
          .limit(1)
          .get();

      if (driverSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No free drivers available')),
        );
        return;
      }

      final driverDoc = driverSnap.docs.first;
      final driverData = driverDoc.data();
      final driverId = driverDoc.id;

      await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
        'status': 'accepted',
        'driverId': driverId,
        'driverName': driverData['name'],
        'driverPhone': driverData['phone'],
      });

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({'isFree': false});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted and driver assigned')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting request: $e')),
      );
    }
  }

  Future<void> _denyRequest(BuildContext context, String docId) async {
    TextEditingController reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Request'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter reason for rejection',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Submit'),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;

                try {
                  await FirebaseFirestore.instance
                      .collection('bookings')
                      .doc(docId)
                      .update({
                    'status': 'rejected',
                    'rejectionReason': reason,
                  });

                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request rejected')),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error rejecting request: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
