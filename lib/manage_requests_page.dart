import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
            return const Center(child: Text('No pending requests.'));
          }

          final docs = snapshot.data!.docs;

          const List<String> priorityOrder = [
            'principal@tce.edu',
            'hod@tce.edu',
            'deanacad@tce.edu'
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
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['eventName'] ?? 'Untitled Event',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Pickup: ${data['pickupDate']} at ${data['pickupTime']} from ${data['pickupLocation']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Drop: ${data['dropDate']} at ${data['dropTime']} to ${data['dropLocation']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Persons: ${data['numberOfPersons']} | Facility: ${data['facility']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Resource Person: ${data['resourcePerson']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Forwarded Through: ${data['forwardThrough']}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Requested by: ${data['facultyEmail']}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                onPressed: () => _acceptRequest(context, doc.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                label: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _denyRequest(context, doc.id),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                label: const Text(
                                  'Reject',
                                  style: TextStyle(color: Colors.red),
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
