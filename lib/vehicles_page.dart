import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _numberPlateController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  String? selectedVehicleName;
  String? editingDocId;

  final Map<String, IconData> vehicleIconMap = {
    'Car': Icons.directions_car,
    'EV Auto': Icons.electric_rickshaw,
    'EV Buggy': Icons.electric_bike,
    'Sumo': Icons.airport_shuttle,
    'Bus': Icons.directions_bus,
  };

  @override
  void dispose() {
    _numberPlateController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  void _showVehicleDialog({
    String? name,
    String? numberPlate,
    String? brand,
    String? docId,
  }) {
    selectedVehicleName = name;
    _numberPlateController.text = numberPlate ?? '';
    _brandController.text = brand ?? '';
    editingDocId = docId;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            docId == null ? 'Add Vehicle' : 'Edit Vehicle',
            style: GoogleFonts.poppins(
              color: Colors.blue[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedVehicleName,
                  items: vehicleIconMap.keys.map((name) {
                    return DropdownMenuItem(
                      value: name,
                      child: Row(
                        children: [
                          Icon(vehicleIconMap[name], color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(name, style: GoogleFonts.poppins()),
                        ],
                      ),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    labelText: 'Vehicle Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() {
                    selectedVehicleName = val;
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _numberPlateController,
                  decoration: InputDecoration(
                    labelText: 'Number Plate',
                    prefixIcon: const Icon(Icons.confirmation_number, color: Colors.blue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                if (selectedVehicleName?.toLowerCase() == 'car')
                  TextField(
                    controller: _brandController,
                    decoration: InputDecoration(
                      labelText: 'Brand',
                      prefixIcon: const Icon(Icons.branding_watermark, color: Colors.blue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                selectedVehicleName = null;
                _numberPlateController.clear();
                _brandController.clear();
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
                final name = selectedVehicleName;
                final numberPlate = _numberPlateController.text.trim();
                final brand = _brandController.text.trim();

                if (name == null || name.isEmpty || numberPlate.isEmpty) return;
                if (name.toLowerCase() == 'car' && brand.isEmpty) return;

                final data = {
                  'name': name,
                  'numberPlate': numberPlate,
                  if (name.toLowerCase() == 'car') 'brand': brand,
                };

                if (editingDocId == null) {
                  await _firestore.collection('new_vehicles').add({
                    ...data,
                    'pickup_bookings': [],
                    'drop_bookings': [],
                  });
                } else {
                  await _firestore.collection('new_vehicles').doc(editingDocId).update(data);
                }

                selectedVehicleName = null;
                _numberPlateController.clear();
                _brandController.clear();
                editingDocId = null;
                Navigator.pop(context);
              },
              child: Text(
                editingDocId == null ? 'Add' : 'Update',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteVehicle(String docId) {
    _firestore.collection('new_vehicles').doc(docId).delete();
  }

  void _showPendingBookingsDialog(
      List<dynamic> pickupBookings, List<dynamic> dropBookings) {
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
              if (pickupBookings.isNotEmpty) ...[
                Text(
                  'Pending Pickups',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[700],
                  ),
                ),
                const Divider(),
                ...pickupBookings.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> booking = Map<String, dynamic>.from(entry.value);
                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('new_drivers').doc(booking['driverId']).get(),
                    builder: (context, driverSnapshot) {
                      if (driverSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!driverSnapshot.hasData || !driverSnapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }
                      final driverData = driverSnapshot.data!.data() as Map<String, dynamic>;
                      final driverName = driverData['name'] ?? 'N/A';
                      final driverPhone = driverData['phone'] ?? 'N/A';
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
                            ListTile(
                              title: Text(
                                "Driver: $driverName",
                                style: GoogleFonts.poppins(),
                              ),
                              subtitle: Text(
                                "Phone: $driverPhone",
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
              if (dropBookings.isNotEmpty) ...[
                Text(
                  'Pending Drops',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey[700],
                  ),
                ),
                const Divider(),
                ...dropBookings.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> booking = Map<String, dynamic>.from(entry.value);
                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('new_drivers').doc(booking['driverId']).get(),
                    builder: (context, driverSnapshot) {
                      if (driverSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!driverSnapshot.hasData || !driverSnapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }
                      final driverData = driverSnapshot.data!.data() as Map<String, dynamic>;
                      final driverName = driverData['name'] ?? 'N/A';
                      final driverPhone = driverData['phone'] ?? 'N/A';
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
                            ListTile(
                              title: Text(
                                "Driver: $driverName",
                                style: GoogleFonts.poppins(),
                              ),
                              subtitle: Text(
                                "Phone: $driverPhone",
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
              if (pickupBookings.isEmpty && dropBookings.isEmpty)
                Text(
                  'No pending bookings found.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text(
          'Vehicles',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[800],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('new_vehicles').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final vehicles = snapshot.data?.docs ?? [];
          if (vehicles.isEmpty) {
            return Center(
              child: Text(
                'No vehicles found.',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final doc = vehicles[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? '';
              final plate = data['numberPlate'] ?? '';
              final brand = data['brand'] ?? '';
              final List<dynamic> pickupBookings = data['pickup_bookings'] ?? [];
              final List<dynamic> dropBookings = data['drop_bookings'] ?? [];

              // Filter for 'Pending' bookings
              final List<dynamic> pendingPickupBookings =
                  pickupBookings.where((booking) => booking['tripStatus'] == 'Pending').toList();
              final List<dynamic> pendingDropBookings =
                  dropBookings.where((booking) => booking['tripStatus'] == 'Pending').toList();

              final bool hasPendingBookings =
                  pendingPickupBookings.isNotEmpty || pendingDropBookings.isNotEmpty;
              final iconData = vehicleIconMap[name] ?? Icons.directions_car;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              radius: 30,
                              child: Icon(iconData, color: Colors.blue.shade800, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    )),
                                const SizedBox(height: 4),
                                Text(plate,
                                    style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87)),
                                if (brand.isNotEmpty)
                                  Text("Brand: $brand",
                                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[800])),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Icon(
                                    hasPendingBookings ? Icons.cancel : Icons.check_circle,
                                    color: hasPendingBookings ? Colors.red : Colors.green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasPendingBookings ? 'Occupied' : 'Available',
                                    style: GoogleFonts.poppins(
                                      color: hasPendingBookings ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ]),
                          // Hide/Show Edit & Delete buttons
                          if (!hasPendingBookings)
                            Column(children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showVehicleDialog(
                                  name: name,
                                  numberPlate: plate,
                                  docId: doc.id,
                                  brand: brand,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteVehicle(doc.id),
                              ),
                            ]),
                        ],
                      ),
                      if (hasPendingBookings) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showPendingBookingsDialog(
                              pendingPickupBookings, pendingDropBookings),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVehicleDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Vehicle', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.blue[800],
      ),
    );
  }
}