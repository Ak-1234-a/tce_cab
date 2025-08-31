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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final name = _nameController.text.trim();
              final phone = _phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) return;

              if (editingDocId == null) {
                await _firestore.collection('new_drivers').add({
                  'name': name,
                  'phone': phone,
                  'pickup_bookings': [],
                  'drop_bookings': [],
                });
              } else {
                await _firestore.collection('new_drivers').doc(editingDocId).update({
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

  Future<Map<String, dynamic>?> _getVehicleDetails(String vehicleId) async {
    if (vehicleId.isEmpty) return null;
    try {
      final docSnapshot = await _firestore.collection('new_vehicles').doc(vehicleId).get();
      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      return null;
    } catch (e) {
      print("Error fetching vehicle details: $e");
      return null;
    }
  }

  void _showPendingBookingsDialog(List<dynamic> pickupBookings, List<dynamic> dropBookings) {
    // Filter bookings to only show those with 'Pending' status
    final pendingPickupBookings = pickupBookings.where((booking) => booking['tripStatus'] == 'Pending').toList();
    final pendingDropBookings = dropBookings.where((booking) => booking['tripStatus'] == 'Pending').toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Pending Trips',
          style: GoogleFonts.poppins(
            color: Colors.blue[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pendingPickupBookings.isNotEmpty) ...[
                Text(
                  'Pending Pickups',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[700],
                  ),
                ),
                const Divider(),
                ...pendingPickupBookings.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> booking = Map<String, dynamic>.from(entry.value);

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getVehicleDetails(booking['vehicleId']),
                    builder: (context, vehicleSnapshot) {
                      final vehicleData = vehicleSnapshot.data;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold, color: Colors.blue[800]),
                            ),
                          ),
                          title: Text(
                            'From: ${booking['pickupFrom'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'To: ${booking['pickupTo'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(color: Colors.grey[700]),
                          ),
                          children: [
                            if (vehicleSnapshot.connectionState == ConnectionState.waiting)
                              const LinearProgressIndicator(),
                            if (vehicleData != null)
                              ListTile(
                                title: Text(
                                  "Vehicle Details",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                subtitle: Text(
                                  "Type: ${vehicleData['name'] ?? 'N/A'}\nNumber Plate: ${vehicleData['numberPlate'] ?? 'N/A'}",
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                            ListTile(
                              title: Text(
                                "Date: ${booking['pickupDate'] ?? 'N/A'}",
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                            ListTile(
                              title: Text(
                                "Time: ${booking['pickupTime'] ?? 'N/A'}",
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
                const SizedBox(height: 16),
              ],
              if (pendingDropBookings.isNotEmpty) ...[
                Text(
                  'Pending Drops',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[700],
                  ),
                ),
                const Divider(),
                ...pendingDropBookings.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> booking = Map<String, dynamic>.from(entry.value);

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getVehicleDetails(booking['vehicleId']),
                    builder: (context, vehicleSnapshot) {
                      final vehicleData = vehicleSnapshot.data;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold, color: Colors.blue[800]),
                            ),
                          ),
                          title: Text(
                            'From: ${booking['dropFrom'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'To: ${booking['dropTo'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(color: Colors.grey[700]),
                          ),
                          children: [
                            if (vehicleSnapshot.connectionState == ConnectionState.waiting)
                              const LinearProgressIndicator(),
                            if (vehicleData != null)
                              ListTile(
                                title: Text(
                                  "Vehicle Details",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                subtitle: Text(
                                  "Type: ${vehicleData['name'] ?? 'N/A'}\nNumber Plate: ${vehicleData['numberPlate'] ?? 'N/A'}",
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                            ListTile(
                              title: Text(
                                "Date: ${booking['dropDate'] ?? 'N/A'}",
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                            ListTile(
                              title: Text(
                                "Time: ${booking['dropTime'] ?? 'N/A'}",
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              ],
              if (pendingPickupBookings.isEmpty && pendingDropBookings.isEmpty)
                Text(
                  'No pending Trips found.',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: Colors.blue[800])),
          ),
        ],
      ),
    );
  }

  void _deleteDriver(String docId) {
    _firestore.collection('new_drivers').doc(docId).delete();
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
            stream: _firestore.collection('new_drivers').snapshots(),
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
                  final List<dynamic> pickupBookings = data['pickup_bookings'] ?? [];
                  final List<dynamic> dropBookings = data['drop_bookings'] ?? [];

                  // Check if any booking has 'Pending' status
                  final bool hasPendingBookings = pickupBookings.any((booking) => booking['tripStatus'] == 'Pending') ||
                      dropBookings.any((booking) => booking['tripStatus'] == 'Pending');

                  final bool isAssigned = hasPendingBookings;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.blue.shade100,
                                child: const Icon(Icons.person, color: Colors.blue, size: 30),
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
                                      data['phone'] ?? '',
                                      style: GoogleFonts.poppins(
                                          fontSize: 15, color: Colors.grey[800]),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          isAssigned ? Icons.cancel : Icons.check_circle,
                                          color: isAssigned ? Colors.red : Colors.green,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isAssigned ? 'Assigned' : 'Available',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: isAssigned ? Colors.red : Colors.green,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!isAssigned) // Don't show edit/delete if driver is assigned
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
                          if (hasPendingBookings) ...[ // Only show button if there are pending bookings
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showPendingBookingsDialog(pickupBookings, dropBookings),
                              icon: const Icon(Icons.event, color: Colors.white),
                              label: Text(
                                'View Pending Trips',
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
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