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
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text('No pending requests.', style: GoogleFonts.poppins(fontSize: 16)),
            );
          }

          const priorityOrder = [
            'principal@tce.edu',
            'hod@tce.edu',
            'deanacad@tce.edu',
          ];

          docs.sort((a, b) {
            int ap = priorityOrder.indexWhere((e) => a['facultyEmail'].contains(e));
            int bp = priorityOrder.indexWhere((e) => b['facultyEmail'].contains(e));
            ap = ap == -1 ? 100 : ap;
            bp = bp == -1 ? 100 : bp;
            if (ap != bp) return ap.compareTo(bp);
            return (a['timestamp'] as Timestamp).compareTo(b['timestamp'] as Timestamp);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return BookingCard(
                data: data,
                onAccept: () => _onAccept(context, doc.id, data),
                onReject: () => _denyRequest(context, doc.id),
              );
            },
          );
        },
      ),
    );
  }

  void _onAccept(BuildContext ctx, String bookingId, Map<String, dynamic> bookingData) async {
    // Step 1: Select Vehicle
    final vehicleSnap = await FirebaseFirestore.instance
        .collection('vehicles')
        .where('isFree', isEqualTo: true)
        .where('name', isEqualTo: bookingData['facility'] ?? '')
        .get();

    if (vehicleSnap.docs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No free vehicles available')));
      return;
    }

    String? selectedVehicleId;
    Map<String, dynamic>? selectedVehicle;

    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Select Vehicle', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: vehicleSnap.docs.map((v) {
              final vd = v.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text('${vd['name']} – ${vd['numberPlate']}'),
                  subtitle: vd.containsKey('brand') ? Text(vd['brand']) : null,
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
    if (selectedVehicleId == null) return;

    // Step 2: Select Driver
    final driverSnap = await FirebaseFirestore.instance
        .collection('drivers')
        .where('isFree', isEqualTo: true)
        .get();

    if (driverSnap.docs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No free drivers available')));
      return;
    }

    String? selectedDriverId;
    Map<String, dynamic>? selectedDriver;

    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Select Driver', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: driverSnap.docs.map((d) {
              final dd = d.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.person),
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
    if (selectedDriverId == null) return;

    // Step 3: Assign and Show Success
    await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
      'status': 'accepted',
      'vehicleId': selectedVehicleId,
      'vehicleName': selectedVehicle!['name'],
      'vehicleNumberPlate': selectedVehicle!['numberPlate'],
      'driverId': selectedDriverId,
      'driverName': selectedDriver!['name'],
      'driverPhone': selectedDriver!['phone'],
    });

    await FirebaseFirestore.instance.collection('vehicles').doc(selectedVehicleId).update({'isFree': false});
    await FirebaseFirestore.instance.collection('drivers').doc(selectedDriverId).update({'isFree': false});

    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Booking has been accepted and driver & vehicle assigned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _denyRequest(BuildContext ctx, String bookingId) async {
    final reasonCtrl = TextEditingController();
    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final r = reasonCtrl.text.trim();
              if (r.isEmpty) return;
              await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
                'status': 'rejected',
                'rejectionReason': r,
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Request rejected')));
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAccept, onReject;

  const BookingCard({super.key, required this.data, required this.onAccept, required this.onReject});

  Widget _row(IconData i, String l, String v) {
    return Row(children: [
      Icon(i, size: 18, color: Colors.blueGrey),
      const SizedBox(width: 8),
      Expanded(child: RichText(
        text: TextSpan(text: '$l ', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
        children: [TextSpan(text: v, style: GoogleFonts.poppins(fontWeight: FontWeight.normal, color: Colors.black87))]),
      )),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['eventName'] ?? 'Event', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blue[900])),
            const SizedBox(height: 12),
            _row(Icons.calendar_month, 'Pickup:', '${data['pickupDate']} ${data['pickupTime']} at ${data['pickupLocation']}'),
            const SizedBox(height: 6),
            _row(Icons.place, 'Drop:', '${data['dropDate']} ${data['dropTime']} to ${data['dropLocation']}'),
            const SizedBox(height: 10),
            _row(Icons.people, 'Persons:', '${data['numberOfPersons']}'),
            _row(Icons.school, 'Facility:', data['facility'] ?? ''),
            _row(Icons.person, 'Resource:', data['resourcePerson'] ?? ''),
            _row(Icons.forward, 'Forwarded:', data['forwardThrough'] ?? ''),
            _row(Icons.email, 'Requested by:', data['facultyEmail'] ?? ''),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.check_circle_outline), onPressed: onAccept, style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600), label: Text('Accept', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.cancel_outlined, color: Colors.red), onPressed: onReject, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)), label: Text('Reject', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600)))),
            ]),
          ]),
        ),
      ),
    );
  }
}
