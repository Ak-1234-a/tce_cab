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
                // Add new driver with isFree: false
                await _firestore.collection('drivers').add({
                  'name': name,
                  'phone': phone,
                  'isFree': false,
                });
              } else {
                // Update existing driver
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
      body: StreamBuilder<QuerySnapshot>(
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
            padding: const EdgeInsets.all(12),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final doc = drivers[index];
              final data = doc.data() as Map<String, dynamic>;
              final isFree = data['isFree'] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Row(
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
                              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[800]),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  isFree ? Icons.check_circle : Icons.cancel,
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
                            )
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
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDriverDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add New Driver',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.blue[800],
      ),
    );
  }
}
