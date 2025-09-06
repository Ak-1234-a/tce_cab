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
  final _pickupFromController = TextEditingController();
  final _pickupToController = TextEditingController();
  final _dropFromController = TextEditingController();
  final _dropToController = TextEditingController();
  final _numberOfPersonsController = TextEditingController();
  final _otherDepartmentController = TextEditingController(); // New controller for 'Others'

  String? _selectedFacility;
  String? _selectedTripType;
  String? _selectedDepartment;

  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;
  DateTime? _dropDate;
  TimeOfDay? _dropTime;

  bool _isLoading = false; // New state variable for loading

  final List<String> _departments = [
    'Information Technology',
    'Computer Science and Engineering',
    'Computer Science and Business System',
    'Mechanical',
    'Mechatronics',
    'TSEDA',
    'Civil',
    'Applied Mathematics and Computational Science',
    'Physics',
    'Chemistry',
    'Electronics and communication Engineering',
    'Electrical and Electronics Engineering',
    'English',
    'Computer Applications',
    'Others', // Added 'Others'
  ];

  String get _facultyName {
    final parts = widget.facultyEmail.split('@').first.split('.');
    return parts.map((p) => StringCasingExtension(p).capitalize()).join(' ');
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _resourcePersonController.dispose();
    _pickupFromController.dispose();
    _pickupToController.dispose();
    _dropFromController.dispose();
    _dropToController.dispose();
    _numberOfPersonsController.dispose();
    _otherDepartmentController.dispose(); // Dispose the new controller
    super.dispose();
  }

  Future<void> _selectDate(BuildContext ctx, bool isPickup) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
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
    // Basic validation for common fields
    if (_selectedFacility == null ||
        _eventNameController.text.isEmpty ||
        _resourcePersonController.text.isEmpty ||
        _selectedDepartment == null ||
        _selectedTripType == null ||
        _numberOfPersonsController.text.isEmpty ||
        _pickupFromController.text.isEmpty ||
        _pickupToController.text.isEmpty ||
        _pickupDate == null ||
        _pickupTime == null ||
        (_selectedDepartment == 'Others' && _otherDepartmentController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    final int? numberOfPersons = int.tryParse(_numberOfPersonsController.text);
    if (numberOfPersons == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid number of persons')));
      return;
    }

    if (_selectedFacility == 'Bus' && numberOfPersons > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bus can accommodate up to 100 persons')));
      return;
    } else if (_selectedFacility != 'Bus' && numberOfPersons > 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Other facilities can accommodate up to 10 persons')));
      return;
    }

    final pickupDateTime = DateTime(
      _pickupDate!.year,
      _pickupDate!.month,
      _pickupDate!.day,
      _pickupTime!.hour,
      _pickupTime!.minute,
    );

    // Validation for Round Trip
    if (_selectedTripType == 'Round Trip') {
      if (_dropDate == null ||
          _dropTime == null ||
          _dropFromController.text.isEmpty ||
          _dropToController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields for Round Trip')));
        return;
      }
      final dropDateTime = DateTime(
        _dropDate!.year,
        _dropDate!.month,
        _dropDate!.day,
        _dropTime!.hour,
        _dropTime!.minute,
      );

      if (!dropDateTime.isAfter(pickupDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drop date/time must be after pickup date/time')));
        return;
      }

      if (dropDateTime.difference(pickupDateTime).inDays > 7) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bookings must be completed within a week')));
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'facultyEmail': widget.facultyEmail,
        'eventName': _eventNameController.text,
        'resourcePerson': _resourcePersonController.text,
        'forwardThrough': 'Manager',
        'facility': _selectedFacility,
        'tripType': _selectedTripType,
        'numberOfPersons': _numberOfPersonsController.text,
        'department': _selectedDepartment == 'Others' ? _otherDepartmentController.text : _selectedDepartment,
        'pickupFrom': _pickupFromController.text,
        'pickupTo': _pickupToController.text,
        'pickupDate': _formatDate(_pickupDate),
        'pickupTime': _formatTime(_pickupTime),
        'pickup_status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Conditionally add drop details and status for Round Trip
      if (_selectedTripType == 'Round Trip') {
        data.addAll({
          'dropFrom': _dropFromController.text,
          'dropTo': _dropToController.text,
          'dropDate': _formatDate(_dropDate),
          'dropTime': _formatTime(_dropTime),
          'drop_status': 'Pending',
        });
      }

      await FirebaseFirestore.instance.collection('new_bookings').add(data);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking submitted successfully')));
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _eventNameController.clear();
    _resourcePersonController.clear();
    _pickupFromController.clear();
    _pickupToController.clear();
    _dropFromController.clear();
    _dropToController.clear();
    _numberOfPersonsController.clear();
    _otherDepartmentController.clear(); // Clear the new controller
    setState(() {
      _selectedFacility = null;
      _selectedTripType = null;
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
              _buildDropdown(
                label: 'Trip Type',
                icon: Icons.alt_route,
                value: _selectedTripType,
                items: ['Single Trip', 'Round Trip'],
                onChanged: (v) => setState(() => _selectedTripType = v),
              ),
              _buildTextField(_eventNameController, 'Event Name', Icons.event),
              _buildTextField(_resourcePersonController, 'Resource Person', Icons.person),
              _buildTextField(_numberOfPersonsController, 'No. of Persons', Icons.people, keyboardType: TextInputType.number),
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
              _buildDropdown(
                label: 'Department',
                icon: Icons.apartment,
                value: _selectedDepartment,
                items: _departments,
                onChanged: (v) => setState(() => _selectedDepartment = v),
              ),
              if (_selectedDepartment == 'Others')
                _buildTextField(_otherDepartmentController, 'Other Department', Icons.edit),
            ]),
            const SizedBox(height: 20),
            _buildCard('Pickup Booking', [
              _buildTextField(_pickupFromController, 'From', Icons.my_location),
              _buildTextField(_pickupToController, 'To', Icons.location_on),
              _buildDateTimeRow(true),
            ]),
            if (_selectedTripType == 'Round Trip') ...[
              const SizedBox(height: 20),
              _buildCard('Drop Booking', [
                _buildTextField(_dropFromController, 'From', Icons.my_location),
                _buildTextField(_dropToController, 'To', Icons.location_on),
                _buildDateTimeRow(false),
              ]),
            ],
            const SizedBox(height: 20),
            _buildSummaryCard(),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.send, color: Colors.white),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Padding(
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
                onPressed: _isLoading ? null : _submitBooking,
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
            Navigator.pop(context);

            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('isFacultyLoggedIn');
            await prefs.remove('facultyEmail');

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
            ...fields.map(
                  (w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: w,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Summary',
              style: GoogleFonts.openSans(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Facility', _selectedFacility),
            _buildSummaryRow('Trip Type', _selectedTripType),
            _buildSummaryRow('Event Name', _eventNameController.text),
            _buildSummaryRow('Resource Person', _resourcePersonController.text),
            _buildSummaryRow('Department', _selectedDepartment == 'Others' ? _otherDepartmentController.text : _selectedDepartment),
            _buildSummaryRow('No. of Persons', _numberOfPersonsController.text),
            const Divider(),
            _buildSummaryRow('Pickup From', _pickupFromController.text),
            _buildSummaryRow('Pickup To', _pickupToController.text),
            _buildSummaryRow('Pickup Date', _formatDate(_pickupDate)),
            _buildSummaryRow('Pickup Time', _formatTime(_pickupTime)),
            if (_selectedTripType == 'Round Trip') ...[
              const Divider(),
              _buildSummaryRow('Drop From', _dropFromController.text),
              _buildSummaryRow('Drop To', _dropToController.text),
              _buildSummaryRow('Drop Date', _formatDate(_dropDate)),
              _buildSummaryRow('Drop Time', _formatTime(_dropTime)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.openSans(
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.openSans(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: ctl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blue),
        labelText: label,
        labelStyle: GoogleFonts.openSans(color: Colors.blue.shade900),
        border: const OutlineInputBorder(),
      ),
      style: GoogleFonts.openSans(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        return null;
      },
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
      width: double.infinity,
      child: DropdownButtonFormField<String>(
        value: value,
        menuMaxHeight: 300,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blue),
          labelText: label,
          labelStyle: GoogleFonts.openSans(color: Colors.blue.shade900),
          border: const OutlineInputBorder(),
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(
            value: e,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(e, style: GoogleFonts.openSans()),
            ),
          ),
        )
            .toList(),
        onChanged: onChanged,
        style: GoogleFonts.openSans(color: Colors.black),
        isExpanded: true,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select an option';
          }
          return null;
        },
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