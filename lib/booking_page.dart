import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'view_bookings_page.dart';
import 'calendar_page.dart';

class BookingPage extends StatefulWidget {
  final String facultyEmail;

  const BookingPage({super.key, required this.facultyEmail});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _eventNameController = TextEditingController();
  final _resourcePersonController = TextEditingController();
  final _forwardThroughController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _dropLocationController = TextEditingController();

  String? _selectedFacility;
  String? _selectedPersons;

  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;
  DateTime? _dropDate;
  TimeOfDay? _dropTime;

  String get _facultyName {
    final parts = widget.facultyEmail.split('@').first.split('.');
    return parts.map((p) => p.capitalize()).join(' ');
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _resourcePersonController.dispose();
    _forwardThroughController.dispose();
    _pickupLocationController.dispose();
    _dropLocationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext ctx, bool isPickup) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isPickup) {
          _pickupDate = picked;
        } else {
          _dropDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext ctx, bool isPickup) async {
    final picked = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isPickup) {
          _pickupTime = picked;
        } else {
          _dropTime = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? d) =>
      d != null ? "${d.day}/${d.month}/${d.year}" : '';
  String _formatTime(TimeOfDay? t) => t != null ? t.format(context) : '';

  Future<void> _submitBooking() async {
    if (_selectedFacility == null ||
        _eventNameController.text.isEmpty ||
        _resourcePersonController.text.isEmpty ||
        _forwardThroughController.text.isEmpty ||
        _pickupLocationController.text.isEmpty ||
        _dropLocationController.text.isEmpty ||
        _pickupDate == null ||
        _pickupTime == null ||
        _dropDate == null ||
        _dropTime == null ||
        _selectedPersons == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final data = {
      'facultyEmail': widget.facultyEmail,
      'eventName': _eventNameController.text,
      'resourcePerson': _resourcePersonController.text,
      'forwardThrough': _forwardThroughController.text,
      'facility': _selectedFacility,
      'pickupLocation': _pickupLocationController.text,
      'dropLocation': _dropLocationController.text,
      'pickupDate': _formatDate(_pickupDate),
      'pickupTime': _formatTime(_pickupTime),
      'dropDate': _formatDate(_dropDate),
      'dropTime': _formatTime(_dropTime),
      'numberOfPersons': _selectedPersons,
      'status': 'Pending',
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('bookings').add(data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking submitted successfully')),
      );
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _clearForm() {
    _eventNameController.clear();
    _resourcePersonController.clear();
    _forwardThroughController.clear();
    _pickupLocationController.clear();
    _dropLocationController.clear();
    setState(() {
      _selectedFacility = null;
      _selectedPersons = null;
      _pickupDate = null;
      _pickupTime = null;
      _dropDate = null;
      _dropTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.blue.shade800,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundImage: AssetImage('assets/TCE.png'),
              radius: 18,
            ),
            const SizedBox(width: 10),
            Text(
              'TCE Cab Booking',
              style: GoogleFonts.lobster(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _facultyName[0],
                style: const TextStyle(
                    color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $_facultyName 👋',
              style: GoogleFonts.openSans(
                fontSize: 24,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            _buildCard('Event Details', [
              _buildDropdown(
                label: 'Facility',
                icon: Icons.directions_car,
                value: _selectedFacility,
                items: ['Car', 'Van', 'Bus'],
                onChanged: (v) => setState(() => _selectedFacility = v),
              ),
              _buildTextField(_eventNameController, 'Event Name', Icons.event),
              _buildTextField(
                  _resourcePersonController, 'Resource Person', Icons.person),
              _buildTextField(
                  _forwardThroughController, 'Forward Through', Icons.forward),
            ]),
            const SizedBox(height: 20),
            _buildCard('Vehicle Booking', [
              _buildTextField(
                  _pickupLocationController, 'Pickup Location', Icons.my_location),
              _buildTextField(
                  _dropLocationController, 'Drop Location', Icons.location_on),
              _buildDateTimeRow(true),
              _buildDateTimeRow(false),
              _buildDropdown(
                label: 'Persons',
                icon: Icons.people,
                value: _selectedPersons,
                items: List.generate(10, (i) => '${i + 1}'),
                onChanged: (v) => setState(() => _selectedPersons = v),
              ),
            ]),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send, color: Colors.white),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Submit Booking',
                    style: GoogleFonts.openSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _submitBooking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() => Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue.shade800),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/TCE.png'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _facultyName,
                    style: GoogleFonts.openSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('My Bookings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ViewBookingsPage(email: widget.facultyEmail),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Calendar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CalendarPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
            ),
          ],
        ),
      );

  Widget _buildCard(String title, List<Widget> fields) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Text(
                  title,
                  style: GoogleFonts.openSans(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 16),
              ] +
              fields
                  .map((w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: w,
                      ))
                  .toList(),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctl, String label, IconData icon) {
    return TextFormField(
      controller: ctl,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blue),
        labelText: label,
        labelStyle: GoogleFonts.openSans(color: Colors.blue.shade900),
        border: const OutlineInputBorder(),
      ),
      style: GoogleFonts.openSans(),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blue),
        labelText: label,
        labelStyle: GoogleFonts.openSans(color: Colors.blue.shade900),
        border: const OutlineInputBorder(),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.openSans())))
          .toList(),
      onChanged: onChanged,
      style: GoogleFonts.openSans(color: Colors.black),
    );
  }

  Widget _buildDateTimeRow(bool isPickup) {
    final date = isPickup ? _pickupDate : _dropDate;
    final time = isPickup ? _pickupTime : _dropTime;
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.calendar_today, color: Colors.blue),
              labelText: isPickup ? 'Pickup Date' : 'Drop Date',
              labelStyle: GoogleFonts.openSans(color: Colors.blue.shade900),
              hintText: date != null ? _formatDate(date) : 'Select date',
              border: const OutlineInputBorder(),
            ),
            style: GoogleFonts.openSans(),
            onTap: () => _selectDate(context, isPickup),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.access_time, color: Colors.blue),
              labelText: isPickup ? 'Pickup Time' : 'Drop Time',
              labelStyle: GoogleFonts.openSans(color: Colors.blue.shade900),
              hintText: time != null ? _formatTime(time) : 'Select time',
              border: const OutlineInputBorder(),
            ),
            style: GoogleFonts.openSans(),
            onTap: () => _selectTime(context, isPickup),
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return this[0].toUpperCase() + substring(1);
  }
}
