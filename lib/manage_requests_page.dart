import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ManageRequestsPage extends StatelessWidget {
  const ManageRequestsPage({super.key});

  static const String brevoApiKey =
      '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';

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
          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No pending requests.',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            );
          }

          const priorityOrder = [
            'principal@tce.edu',
            'hodit@tce.edu',
            'hodcse@tce.edu',
            'deanacad@tce.edu',
          ];

          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            int ap = priorityOrder.indexWhere(
                (e) => aData['facultyEmail']?.contains(e) ?? false);
            int bp = priorityOrder.indexWhere(
                (e) => bData['facultyEmail']?.contains(e) ?? false);
            ap = ap == -1 ? 100 : ap;
            bp = bp == -1 ? 100 : bp;
            if (ap != bp) return ap.compareTo(bp);
            return (aData['timestamp'] as Timestamp)
                .compareTo(bData['timestamp'] as Timestamp);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return BookingCardWrapper(
                docId: doc.id,
                data: data,
                onAccept: () => _onAccept(ctx, doc.id, data),
                onReject: () => _onReject(ctx, doc.id, data),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onAccept(
      BuildContext ctx, String id, Map<String, dynamic> data) async {
    // Vehicle selection logic
    final vehicleSnap = await FirebaseFirestore.instance
        .collection('vehicles')
        .where('isFree', isEqualTo: true)
        .where('name', isEqualTo: data['facility'] ?? '')
        .get();

    if (vehicleSnap.docs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('No free vehicles available')));
      return;
    }

    String? selectedVehicleId;
    Map<String, dynamic>? selectedVehicle;
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Select Vehicle',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: vehicleSnap.docs.map((v) {
              final vd = v.data();
              return Card(
                child: ListTile(
                  title: Text('${vd['name']} – ${vd['numberPlate']}'),
                  subtitle: Text(vd['brand'] ?? ''),
                  onTap: () {
                    selectedVehicleId = v.id;
                    selectedVehicle = vd;
                    Navigator.pop(ctx);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (selectedVehicleId == null || selectedVehicle == null) return;

    // Driver selection logic
    final driverSnap = await FirebaseFirestore.instance
        .collection('drivers')
        .where('isFree', isEqualTo: true)
        .get();
    if (driverSnap.docs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('No free drivers available')));
      return;
    }

    String? selectedDriverId;
    Map<String, dynamic>? selectedDriver;
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Select Driver',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: driverSnap.docs.map((d) {
              final dd = d.data();
              return Card(
                child: ListTile(
                  title: Text(dd['name'] ?? ''),
                  subtitle: Text(dd['phone'] ?? ''),
                  onTap: () {
                    selectedDriverId = d.id;
                    selectedDriver = dd;
                    Navigator.pop(ctx);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (selectedDriverId == null || selectedDriver == null) return;

    // Update Firestore documents
    final bookingUpdates = {
      'status': 'accepted',
      'vehicleId': selectedVehicleId,
      'vehicleName': selectedVehicle?['name'],
      'vehicleNumberPlate': selectedVehicle?['numberPlate'],
      'driverId': selectedDriverId,
      'driverName': selectedDriver?['name'],
      'driverPhone': selectedDriver?['phone'],
    };
    await FirebaseFirestore.instance.collection('bookings').doc(id).update(bookingUpdates);
    await FirebaseFirestore.instance
        .collection('vehicles')
        .doc(selectedVehicleId)
        .update({'isFree': false});
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(selectedDriverId)
        .update({'isFree': false});

    // Send WhatsApp message to the driver
    final phone = selectedDriver?['phone']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
    if (phone.isNotEmpty) {
      final msg = Uri.encodeComponent('''Hi ${selectedDriver?['name']},

You have been assigned a new booking.

Event: ${data['eventName']}
Pickup: ${data['pickupDate']} at ${data['pickupTime']} from ${data['pickupLocation']}
Drop: ${data['dropDate']} at ${data['dropTime']} to ${data['dropLocation']}
Persons: ${data['numberOfPersons']}
Vehicle: ${selectedVehicle?['name']} – ${selectedVehicle?['numberPlate']}

Regards,
TCE Manager
''');
      final uri = Uri.parse("https://wa.me/91$phone?text=$msg");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch WhatsApp URL: $uri');
      }
    }

    // Send email via Brevo
    final emailResult = await _sendEmailViaBrevo(
      to: data['facultyEmail'],
      subject: 'Booking Accepted: ${data['eventName']}',
      body: '''
Dear Sir/Madam,

Your booking request titled "${data['eventName']}" has been accepted.

Pickup: ${data['pickupDate']} at ${data['pickupTime']} from ${data['pickupLocation']}
Drop: ${data['dropDate']} at ${data['dropTime']} to ${data['dropLocation']}

Driver: ${selectedDriver?['name']} (${selectedDriver?['phone']})
Vehicle: ${selectedVehicle?['name']} – ${selectedVehicle?['numberPlate']}

Regards,
TCE Manager
''',
    );

    if (emailResult) {
      _showDialog(ctx, 'Success',
          'Booking accepted.\n\n• WhatsApp sent to driver.\n• Email sent to faculty.');
      debugPrint('✅ Email sent successfully to ${data['facultyEmail']}');
    } else {
      _showDialog(ctx, 'Partial Success',
          'Booking accepted.\n\n• WhatsApp sent to driver.\n• Failed to send email.');
      debugPrint('❌ Email sending failed for: ${data['facultyEmail']}');
    }
  }

  Future<void> _onReject(
      BuildContext ctx, String id, Map<String, dynamic> data) async {
    final reasonCtrl = TextEditingController();
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Rejection reason', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection('bookings')
                  .doc(id)
                  .update({
                'status': 'rejected',
                'rejectionReason': reason,
              });
              Navigator.pop(ctx);

              final emailResult = await _sendEmailViaBrevo(
                to: data['facultyEmail'],
                subject: 'Booking Rejected: ${data['eventName']}',
                body: '''
Dear Sir/Madam,

We regret to inform you that your booking request "${data['eventName']}" has been rejected.

Reason: $reason

Please contact transport admin for details.

Regards,
TCE Manager
''',
              );

              if (emailResult) {
                _showSnackbar(ctx, 'Request rejected; email sent to faculty.');
                debugPrint('✅ Rejection email sent successfully');
              } else {
                _showSnackbar(ctx, 'Request rejected; failed to send email.');
                debugPrint('❌ Rejection email failed for: ${data['facultyEmail']}');
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<bool> _sendEmailViaBrevo({
    required String? to,
    required String subject,
    required String body,
  }) async {
    if (to == null || to.isEmpty) {
      debugPrint('❌ Email "to" address is empty');
      return false;
    }

    final url = Uri.parse('https://api.brevo.com/v3/smtp/email');
    final payload = {
      "sender": {"name": "TCE Manager", "email": "transport@gen.tce.edu"},
      "to": [
        {"email": to}
      ],
      "subject": subject,
      "htmlContent": "<html><body><pre>$body</pre></body></html>",
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'api-key': brevoApiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode == 201) {
        debugPrint('✅ Email successfully sent to $to');
        return true;
      } else {
        debugPrint('❌ Brevo error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Exception while sending email via Brevo: $e');
      return false;
    }
  }

  void _showDialog(BuildContext ctx, String title, String msg) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showSnackbar(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class BookingCardWrapper extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const BookingCardWrapper({
    super.key,
    required this.docId,
    required this.data,
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
          onAccept: onAccept,
          onReject: onReject,
        );
      },
    );
  }
}

class BookingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAccept, onReject;

  const BookingCard({
    super.key,
    required this.data,
    required this.onAccept,
    required this.onReject,
  });

  Widget _row(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 18, color: Colors.blueGrey),
      const SizedBox(width: 8),
      Expanded(
        child: RichText(
          text: TextSpan(
            text: '$label ',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Colors.black87),
            children: [
              TextSpan(
                text: value,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.normal, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['eventName'] ?? 'Event',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900]),
              ),
              const SizedBox(height: 12),
              _row(Icons.calendar_month, 'Pickup:',
                  '${data['pickupDate']} ${data['pickupTime']} at ${data['pickupLocation']}'),
              const SizedBox(height: 6),
              _row(Icons.place, 'Drop:',
                  '${data['dropDate']} ${data['dropTime']} to ${data['dropLocation']}'),
              const SizedBox(height: 10),
              _row(Icons.people, 'Persons:', '${data['numberOfPersons']}'),
              _row(Icons.school, 'Facility:', data['facility'] ?? ''),
              _row(Icons.person, 'Resource:', data['resourcePerson'] ?? ''),
              _row(Icons.forward, 'Forwarded:', data['forwardThrough'] ?? ''),
              _row(Icons.email, 'Requested by:', data['name'] ?? ''),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600),
                    label: Text('Accept',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red)),
                    label: Text('Reject',
                        style: GoogleFonts.poppins(
                            color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
