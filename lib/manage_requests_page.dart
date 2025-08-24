import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';  // <-- new import

class ManageRequestsPage extends StatefulWidget {
  const ManageRequestsPage({super.key});

  @override
  State<ManageRequestsPage> createState() => _ManageRequestsPageState();
}

class _ManageRequestsPageState extends State<ManageRequestsPage> {
  // TODO: Replace with your WhatsApp Cloud API details
  // Removed phoneNumberId and accessToken since not used anymore for WhatsApp API

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
                onAccept: () => _onAccept(context, doc.id, data),
                onReject: () => _onReject(context, doc.id, data),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onAccept(
      BuildContext context, String id, Map<String, dynamic> data) async {
    // Vehicle selection logic
    final vehicleSnap = await FirebaseFirestore.instance
        .collection('vehicles')
        .where('isFree', isEqualTo: true)
        .where('name', isEqualTo: data['facility'] ?? '')
        .get();

    if (vehicleSnap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No free vehicles available')));
      }
      return;
    }

    String? selectedVehicleId;
    Map<String, dynamic>? selectedVehicle;

    // Show vehicle selection dialog synchronously
    selectedVehicle = await showDialog<Map<String, dynamic>?>(  
      context: context,
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
                    Navigator.of(context).pop({'id': v.id, 'data': vd});
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (selectedVehicle == null) return;

    selectedVehicleId = selectedVehicle['id'] as String?;
    final vehicleData = selectedVehicle['data'] as Map<String, dynamic>?;

    if (selectedVehicleId == null || vehicleData == null) return;

    // Driver selection logic
    final driverSnap = await FirebaseFirestore.instance
        .collection('drivers')
        .where('isFree', isEqualTo: true)
        .get();

    if (driverSnap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No free drivers available')));
      }
      return;
    }

    Map<String, dynamic>? selectedDriver;

    selectedDriver = await showDialog<Map<String, dynamic>?>(  
      context: context,
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
                    Navigator.of(context).pop({'id': d.id, 'data': dd});
                  },
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

    if (selectedDriverId == null || driverData == null) return;

    // Update Firestore documents
    final bookingUpdates = {
      'status': 'accepted',
      'vehicleId': selectedVehicleId,
      'vehicleName': vehicleData['name'],
      'vehicleNumberPlate': vehicleData['numberPlate'],
      'driverId': selectedDriverId,
      'driverName': driverData['name'],
      'driverPhone': driverData['phone'],
    };

    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(id)
        .update(bookingUpdates);
    await FirebaseFirestore.instance
        .collection('vehicles')
        .doc(selectedVehicleId)
        .update({'isFree': false});
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(selectedDriverId)
        .update({'isFree': false});

   final phoneRaw = driverData['phone']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
final phoneNumber = '91$phoneRaw'; // Add country code if needed

// Fetch faculty phone using facultyEmail
String? facultyPhone;

if (data['facultyEmail'] != null) {
  final facultySnap = await FirebaseFirestore.instance
      .collection('faculty_logins')
      .where('email', isEqualTo: data['facultyEmail'])
      .limit(1)
      .get();

  if (facultySnap.docs.isNotEmpty) {
    facultyPhone = facultySnap.docs.first.data()['phone']?.toString();
  }
}

if (phoneRaw.isNotEmpty) {
  final message = '''
Hello ${driverData['name'] ?? 'Driver'},

You have been assigned a new booking:

Event: ${data['eventName'] ?? ''}
Pickup: ${data['pickupDate'] ?? ''} at ${data['pickupTime'] ?? ''} from ${data['pickupLocation'] ?? ''}
Drop: ${data['dropDate'] ?? ''} at ${data['dropTime'] ?? ''} to ${data['dropLocation'] ?? ''}
Vehicle: ${vehicleData['name']} – ${vehicleData['numberPlate']}

Please contact the faculty
Faculty Email: ${data['facultyEmail'] ?? ''}
Faculty no : ${facultyPhone ?? 'Not available'}

Please be prepared.

Regards,
TCE Manager
''';

  await _launchWhatsApp(phoneNumber, message);
}


    // Send email via Brevo (unchanged)
    final emailResult = await _sendEmailViaBrevo(
      to: data['facultyEmail'],
      subject: 'Booking Accepted: ${data['eventName']}',
      body: '''
Dear Sir/Madam,

Your booking request titled "${data['eventName']}" has been accepted.

Pickup: ${data['pickupDate']} at ${data['pickupTime']} from ${data['pickupLocation']}
Drop: ${data['dropDate']} at ${data['dropTime']} to ${data['dropLocation']}

Driver: ${driverData['name']} (${driverData['phone']})
Vehicle: ${vehicleData['name']} – ${vehicleData['numberPlate']}

Regards,
TCE Manager
''',
    );

    if (!mounted) return;

    if (emailResult) {
      _showDialog(context, 'Success',
          'Booking accepted.\n\n• WhatsApp opened for driver.\n• Email sent to faculty.',
          data);
    } else {
      _showDialog(context, 'Partial Success',
          'Booking accepted.\n\n• WhatsApp opened for driver.\n• Failed to send email.',
          data);
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber, String message) async {
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse('https://wa.me/$phoneNumber?text=$encodedMessage');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch WhatsApp');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  // Leave the _sendEmailViaBrevo unchanged as per your instruction
  Future<bool> _sendEmailViaBrevo({
    required String to,
    required String subject,
    required String body,
  }) async {
    const brevoApiKey =
        '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'; // Replace with your API key
    final url = Uri.parse('https://api.brevo.com/v3/smtp/email');
    debugPrint('📩 Sending email to $to with subject "$subject"');
    final Map<String, dynamic> emailData = {
      "sender": {"name": "TCE Manager", "email": "transport@gen.tce.edu"},
      "to": [
        {"email": to}
      ],
      "subject": subject,
      "htmlContent": "<p>${body.replaceAll('\n', '<br>')}</p>"
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'api-key': brevoApiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode(emailData),
      );

      debugPrint('📩 Brevo Response Code: ${response.statusCode}');
      debugPrint('📩 Brevo Response Body: ${response.body}');
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Email sending failed: $e');
      return false;
    }
  }

//changes by arun
  Future<void> _onReject(
    BuildContext context, String id, Map<String, dynamic> data) async {
  final reasonController = TextEditingController();

  final reason = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reject Booking',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Please enter the reason for rejection:',
              style: GoogleFonts.poppins()),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter reason here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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

  // Update booking with rejection and reason
  await FirebaseFirestore.instance.collection('bookings').doc(id).update({
    'status': 'rejected',
    'rejectionReason': reason,
  });

  // Send email to faculty
  final emailSent = await _sendEmailViaBrevo(
    to: data['facultyEmail'],
    subject: 'Booking Rejected: ${data['eventName']}',
    body: '''
Dear Sir/Madam,

We regret to inform you that your booking request titled "${data['eventName']}" has been rejected.

Reason: $reason

Pickup: ${data['pickupDate']} at ${data['pickupTime']} from ${data['pickupLocation']}
Drop: ${data['dropDate']} at ${data['dropTime']} to ${data['dropLocation']}

If you have any questions, please contact the transport office.

Regards,  
TCE Manager
''',
  );

  if (!mounted) return;

  if (emailSent) {
    _showDialog(
      context,
      'Booking Rejected',
      'The booking request has been rejected and an email was sent to the faculty.\n\nReason: $reason',
      data,
    );
  } else {
    _showDialog(
      context,
      'Booking Rejected',
      'The booking request has been rejected.\n\n⚠️ Failed to send email.\n\nReason: $reason',
      data,
    );
  }
}


//changes by arun ends here

  void _showDialog(
      BuildContext context, String title, String message, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog before async op
              final success = await _sendEmailToPrincipal(data);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? 'Email sent to principal.'
                      : 'Failed to send email to principal.')));
            },
            child: const Text('Send Mail to Principal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Future<bool> _sendEmailToPrincipal(Map<String, dynamic> data) async {
    const principalEmail = 'arunkumarje@student.tce.edu';
    final subject = 'Booking Info: ${data['eventName'] ?? 'Event'}';

    final body = '''
Dear Principal,

The following vehicle booking has been accepted:

Event: ${data['eventName']}
Faculty: ${data['facultyEmail']}
Facility: ${data['facility']}
Pickup: ${data['pickupDate']} at ${data['pickupTime']} from ${data['pickupLocation']}
Drop: ${data['dropDate']} at ${data['dropTime']} to ${data['dropLocation']}
No. of Persons: ${data['numberOfPersons']}
Resource Person: ${data['resourcePerson']}
Forwarded Through: ${data['forwardThrough']}

This message is for your information.

Regards,  
TCE Transport Manager
''';

    return await _sendEmailViaBrevo(
      to: principalEmail,
      subject: subject,
      body: body,
    );
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
