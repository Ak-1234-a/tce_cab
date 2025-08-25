import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'view_bookings_page.dart';
import 'calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'faculty_login_page.dart';

class BookingPage extends StatefulWidget {
  final String facultyEmail;

  const BookingPage({super.key, required this.facultyEmail});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _eventNameController = TextEditingController();
  final _resourcePersonController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _dropLocationController = TextEditingController();

  String? _selectedFacility;
  String? _selectedPersons;
  String? _selectedDepartment;

  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;
  DateTime? _dropDate;
  TimeOfDay? _dropTime;

  final List<String> _departments = [
    'Information Technology',
    'Computer Science and Engineering',
    'Computer Science and Business System',
    'Mechanical',
    'Mechatronics',
    'TSEDA',
    'Civil',
    'Applied Mathematics and Computational Science',
    'Maths',
    'Physics',
    'Chemistry',
    'Mathematics',
    'Electronics and communication Engineering',
    'Electrical and Electronics Engineering',
    'English',
    'Computer Applications',
  ];

  String get _facultyName {
    final parts = widget.facultyEmail.split('@').first.split('.');
    return parts.map((p) => p.capitalize()).join(' ');
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _resourcePersonController.dispose();
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
        _pickupLocationController.text.isEmpty ||
        _dropLocationController.text.isEmpty ||
        _selectedDepartment == null ||
        _pickupDate == null ||
        _pickupTime == null ||
        _dropDate == null ||
        _dropTime == null ||
        _selectedPersons == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    // Combine date and time into DateTime objects
    final pickupDateTime = DateTime(
      _pickupDate!.year,
      _pickupDate!.month,
      _pickupDate!.day,
      _pickupTime!.hour,
      _pickupTime!.minute,
    );

    final dropDateTime = DateTime(
      _dropDate!.year,
      _dropDate!.month,
      _dropDate!.day,
      _dropTime!.hour,
      _dropTime!.minute,
    );

    // Check if drop is after pickup
    if (!dropDateTime.isAfter(pickupDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drop date/time must be after pickup date/time'),
        ),
      );
      return;
    }

    final data = {
      'facultyEmail': widget.facultyEmail,
      'eventName': _eventNameController.text,
      'resourcePerson': _resourcePersonController.text,
      'forwardThrough': 'Manager',
      'facility': _selectedFacility,
      'pickupLocation': _pickupLocationController.text,
      'dropLocation': _dropLocationController.text,
      'department': _selectedDepartment,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _clearForm() {
    _eventNameController.clear();
    _resourcePersonController.clear();
    _pickupLocationController.clear();
    _dropLocationController.clear();
    setState(() {
      _selectedFacility = null;
      _selectedPersons = null;
      _selectedDepartment = null;
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
              'TCE Vehicle',
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
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
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
                items: ['Car', 'EV Auto', 'EV Buggy', 'Sumo', 'Bus'],
                onChanged: (v) => setState(() => _selectedFacility = v),
              ),
              _buildTextField(_eventNameController, 'Event Name', Icons.event),
              _buildTextField(
                _resourcePersonController,
                'Resource Person',
                Icons.person,
              ),
              // Forward Through label (non-editable)
              Row(
                children: [
                  Icon(Icons.forward, color: Colors.blue),
                  const SizedBox(width: 12),
                  Text(
                    'Forward Through:',
                    style: GoogleFonts.openSans(
                      color: Colors.blue.shade900,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Manager',
                    style: GoogleFonts.openSans(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              // Department Dropdown
              _buildDropdown(
                label: 'Department',
                icon: Icons.apartment,
                value: _selectedDepartment,
                items: _departments,
                onChanged: (v) => setState(() => _selectedDepartment = v),
              ),
            ]),
            const SizedBox(height: 20),
            _buildCard('Vehicle Booking', [
              _buildTextField(
                _pickupLocationController,
                'Pickup Location',
                Icons.my_location,
              ),
              _buildTextField(
                _dropLocationController,
                'Drop Location',
                Icons.location_on,
              ),
              _buildDateTimeRow(true),
              _buildDateTimeRow(false),
              _buildDropdown(
                label: 'Persons',
                icon: Icons.people,
                value: _selectedPersons,
                items: List.generate(10, (i) => '${i + 1}'),
                onChanged: (v) => setState(() => _selectedPersons = v),
              ),
              const SizedBox(height: 16),
              if (_pickupDate != null)
                Text(
                  'Pickup Date: ${_formatDate(_pickupDate)}',
                  style: GoogleFonts.openSans(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (_pickupTime != null)
                Text(
                  'Pickup Time: ${_formatTime(_pickupTime)}',
                  style: GoogleFonts.openSans(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (_dropDate != null)
                Text(
                  'Drop Date: ${_formatDate(_dropDate)}',
                  style: GoogleFonts.openSans(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (_dropTime != null)
                Text(
                  'Drop Time: ${_formatTime(_dropTime)}',
                  style: GoogleFonts.openSans(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w600,
                  ),
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
                  fontWeight: FontWeight.bold,
                ),
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
          onTap: () async {
            Navigator.pop(context); // Close the drawer

            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('isFacultyLoggedIn'); // Match login key
            await prefs.remove('facultyEmail'); // Optional but clean

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const FacultyLoginPage()),
              (route) => false,
            );
          },
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
          children:
              [
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
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: w,
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctl,
    String label,
    IconData icon,
  ) {
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
    return SizedBox(
      width: double.infinity, // makes dropdown take max width possible
      child: DropdownButtonFormField<String>(
        value: value,
        menuMaxHeight: 300,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blue),
          labelText: label,
          labelStyle: GoogleFonts.openSans(color: Colors.blue.shade900),
          border: const OutlineInputBorder(),
        ),
        items:
            items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: GoogleFonts.openSans()),
                  ),
                )
                .toList(),
        onChanged: onChanged,
        style: GoogleFonts.openSans(color: Colors.black),
        isExpanded:
            true, // important to allow dropdown to expand fully inside SizedBox
      ),
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
              border: const OutlineInputBorder(),
              hintText: date != null ? _formatDate(date) : 'Select Date',
            ),
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
              border: const OutlineInputBorder(),
              hintText: time != null ? _formatTime(time) : 'Select Time',
            ),
            onTap: () => _selectTime(context, isPickup),
          ),
        ),
      ],
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}
