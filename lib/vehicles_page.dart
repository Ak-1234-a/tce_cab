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
  bool isFree = true;

  final Map<String, IconData> vehicleIconMap = {
    'Car': Icons.directions_car,
    'EV Auto': Icons.electric_rickshaw,
    'EV Buggy': Icons.electric_bike,
    'Sumo': Icons.airport_shuttle,
    'Bus': Icons.directions_bus,
  };

  void _showVehicleDialog({
    String? name,
    String? numberPlate,
    String? brand,
    String? docId,
    bool? currentIsFree,
  }) {
    selectedVehicleName = name;
    _numberPlateController.text = numberPlate ?? '';
    _brandController.text = brand ?? '';
    editingDocId = docId;
    isFree = currentIsFree ?? true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
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
                    prefixIcon:
                        const Icon(Icons.confirmation_number, color: Colors.blue),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                if (selectedVehicleName?.toLowerCase() == 'car')
                  TextField(
                    controller: _brandController,
                    decoration: InputDecoration(
                      labelText: 'Brand',
                      prefixIcon:
                          const Icon(Icons.branding_watermark, color: Colors.blue),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.toggle_on, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text("Is Vehicle Available?"),
                    const Spacer(),
                    Switch(
                      value: isFree,
                      onChanged: (value) => setState(() {
                        isFree = value;
                      }),
                      activeColor: Colors.green,
                    ),
                  ],
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = selectedVehicleName;
                final numberPlate =
                    _numberPlateController.text.trim();
                final brand = _brandController.text.trim();

                if (name == null ||
                    name.isEmpty ||
                    numberPlate.isEmpty) return;
                if (name.toLowerCase() == 'car' && brand.isEmpty) return;

                final data = {
                  'name': name,
                  'numberPlate': numberPlate,
                  'isFree': isFree,
                  if (name.toLowerCase() == 'car') 'brand': brand,
                };

                if (editingDocId == null) {
                  await _firestore.collection('vehicles').add(data);
                } else {
                  await _firestore
                      .collection('vehicles')
                      .doc(editingDocId)
                      .update(data);
                }

                selectedVehicleName = null;
                _numberPlateController.clear();
                _brandController.clear();
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
      ),
    );
  }

  void _deleteVehicle(String docId) {
    _firestore.collection('vehicles').doc(docId).delete();
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
      _getCurrentBooking(String numberPlate) async {
    final snap = await _firestore
        .collection('bookings')
        .where('vehicleNumberPlate', isEqualTo: numberPlate)
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
        title: const Text('Vehicles', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[800],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('vehicles').snapshots(),
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
            padding: const EdgeInsets.all(12),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final doc = vehicles[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? '';
              final plate = data['numberPlate'] ?? '';
              final brand = data['brand'] ?? '';
              final free = data['isFree'] ?? true;
              final iconData = vehicleIconMap[name] ?? Icons.directions_car;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          radius: 30,
                          child:
                              Icon(iconData, color: Colors.blue.shade800, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
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
                                  style: GoogleFonts.poppins(
                                      fontSize: 15, color: Colors.black87)),
                              if (brand.isNotEmpty)
                                Text("Brand: $brand",
                                    style: GoogleFonts.poppins(
                                        fontSize: 14, color: Colors.grey[800])),
                              const SizedBox(height: 6),
                              Row(children: [
                                Icon(
                                  free
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color:
                                      free ? Colors.green : Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  free ? 'Available' : 'Occupied',
                                  style: GoogleFonts.poppins(
                                    color:
                                        free ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        Column(children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showVehicleDialog(
                                name: name,
                                numberPlate: plate,
                                docId: doc.id,
                                brand: brand,
                                currentIsFree: free),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteVehicle(doc.id),
                          ),
                        ]),
                      ]),

                      // If occupied, show booking info below
                      if (!free)
                        FutureBuilder<
                            QueryDocumentSnapshot<
                                Map<String, dynamic>>?>(
                          future: _getCurrentBooking(plate),
                          builder: (context, bSnap) {
                            if (bSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: LinearProgressIndicator(),
                              );
                            }
                            final booking = bSnap.data;
                            if (booking == null) {
                              return const SizedBox(); // no booking found
                            }
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
                                      "Currently Booked:",
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blueGrey),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${bd['eventName']} • Dept: ${bd['department'] ?? 'N/A'}",
                                      style: GoogleFonts.poppins(),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Drop: ${bd['dropDate']} at ${bd['dropTime']} → ${bd['dropLocation']}",
                                      style: GoogleFonts.poppins(),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Driver: ${bd['driverName']} (${bd['driverPhone']})",
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ]),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVehicleDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Vehicle', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.blue[800],
      ),
    );
  }
}
