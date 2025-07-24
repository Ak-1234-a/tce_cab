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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberPlateController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  String? editingDocId;
  String currentVehicleName = '';

  // Map vehicle name to Material IconData
  final Map<String, IconData> vehicleIconMap = {
    'Car': Icons.directions_car,
    'EV Auto': Icons.electric_rickshaw,
    'EV Buggy': Icons.electric_bike,
    'Sumo': Icons.airport_shuttle,
    'Bus': Icons.directions_bus,
  };

  void _showVehicleDialog({String? name, String? numberPlate, String? docId, String? brand}) {
    _nameController.text = name ?? '';
    _numberPlateController.text = numberPlate ?? '';
    _brandController.text = brand ?? '';
    editingDocId = docId;
    currentVehicleName = name ?? '';

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
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
                  TextField(
                    controller: _nameController,
                    onChanged: (val) => setState(() {
                      currentVehicleName = val;
                    }),
                    decoration: InputDecoration(
                      labelText: 'Vehicle Name',
                      prefixIcon: const Icon(Icons.directions_car, color: Colors.blue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
                  if (currentVehicleName.trim().toLowerCase() == 'car')
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
                  _nameController.clear();
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
                  final name = _nameController.text.trim();
                  final numberPlate = _numberPlateController.text.trim();
                  final brand = _brandController.text.trim();

                  if (name.isEmpty || numberPlate.isEmpty) return;
                  if (name.toLowerCase() == 'car' && brand.isEmpty) return;

                  final data = {
                    'name': name,
                    'numberPlate': numberPlate,
                    if (name.toLowerCase() == 'car') 'brand': brand,
                  };

                  if (editingDocId == null) {
                    await _firestore.collection('vehicles').add(data);
                  } else {
                    await _firestore.collection('vehicles').doc(editingDocId).update(data);
                  }

                  _nameController.clear();
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
        );
      },
    );
  }

  void _deleteVehicle(String docId) {
    _firestore.collection('vehicles').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Vehicles'),
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
              final numberPlate = data['numberPlate'] ?? '';
              final brand = data['brand'] ?? '';
              final iconData = vehicleIconMap[name] ?? Icons.directions_car;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    radius: 30,
                    child: Icon(
                      iconData,
                      color: Colors.blue.shade800,
                      size: 30,
                    ),
                  ),
                  title: Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  subtitle: Text(
                    brand.isNotEmpty ? "$numberPlate | $brand" : numberPlate,
                    style: GoogleFonts.poppins(fontSize: 15, color: Colors.blue[700]),
                  ),
                  trailing: Wrap(
                    spacing: 12,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showVehicleDialog(
                          name: name,
                          numberPlate: numberPlate,
                          docId: doc.id,
                          brand: brand,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteVehicle(doc.id),
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
        label: Text(
          'Add Vehicle',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.blue[800],
      ),
    );
  }
}
