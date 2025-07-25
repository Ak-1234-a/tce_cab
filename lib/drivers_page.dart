import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class DriversPage extends StatefulWidget {
  const DriversPage({super.key});

  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? editingDocId;

  void _showDriverDialog({String? name, String? phone, String? docId}) {
    _nameController.text = name ?? '';
    _phoneController.text = phone ?? '';
    editingDocId = docId;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          docId == null ? 'Add New Driver' : 'Edit Driver',
          style: GoogleFonts.poppins(
            color: Colors.blue[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                prefixIcon: const Icon(Icons.person, color: Colors.blue),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _nameController.clear();
              _phoneController.clear();
              editingDocId = null;
              Navigator.pop(context);
            },
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final name = _nameController.text.trim();
              final phone = _phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) return;

              if (editingDocId == null) {
                await _firestore.collection('drivers').add({
                  'name': name,
                  'phone': phone,
                  'isFree': true,  // changed to true when adding new driver
                });
              } else {
                await _firestore.collection('drivers').doc(editingDocId).update({
                  'name': name,
                  'phone': phone,
                });
              }

              _nameController.clear();
              _phoneController.clear();
              editingDocId = null;
              Navigator.pop(context);
            },
            child: Text(
              docId == null ? 'Add' : 'Update',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteDriver(String docId) {
    _firestore.collection('drivers').doc(docId).delete();
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _getCurrentBooking(
      String phone) async {
    final snap = await _firestore
        .collection('bookings')
        .where('driverPhone', isEqualTo: phone)
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .get();

    return snap.docs.isNotEmpty ? snap.docs.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Drivers',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('drivers').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final drivers = snapshot.data?.docs ?? [];

              if (drivers.isEmpty) {
                return Center(
                  child: Text(
                    'No drivers found.',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: drivers.length,
                itemBuilder: (context, index) {
                  final doc = drivers[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isFree = data['isFree'] ?? false;
                  final phone = data['phone'] ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.blue.shade100,
                                child: const Icon(Icons.person,
                                    color: Colors.blue, size: 30),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['name'] ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      phone,
                                      style: GoogleFonts.poppins(
                                          fontSize: 15, color: Colors.grey[800]),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          isFree
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: isFree ? Colors.green : Colors.red,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isFree ? 'Available' : 'Occupied',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: isFree ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showDriverDialog(
                                      name: data['name'],
                                      phone: data['phone'],
                                      docId: doc.id,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteDriver(doc.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (!isFree)
                            FutureBuilder<QueryDocumentSnapshot<Map<String, dynamic>>?>(
                              future: _getCurrentBooking(phone),
                              builder: (context, bSnap) {
                                if (bSnap.connectionState == ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: LinearProgressIndicator(),
                                  );
                                }
                                final booking = bSnap.data;
                                if (booking == null) return const SizedBox();

                                final bd = booking.data();
                                return Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Current Booking",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Event: ${bd['eventName'] ?? 'N/A'}",
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ),
                                      Text(
                                        "Drop Date: ${bd['dropDate'] ?? 'N/A'}",
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ),
                                      Text(
                                        "Drop Time: ${bd['dropTime'] ?? 'N/A'}",
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ),
                                      Text(
                                        "Drop Location: ${bd['dropLocation'] ?? 'N/A'}",
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ),
                                      Text(
                                        "Vehicle Type: ${bd['vehicle'] ?? 'N/A'}",
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Add New Driver button positioned bottom-left
          Positioned(
            bottom: 16,
            left: 16,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => _showDriverDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Add New Driver',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
