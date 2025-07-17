import 'package:flutter/material.dart';

class BookingPage extends StatefulWidget {
  final String facultyName;

  const BookingPage({super.key, required this.facultyName});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  // Controllers
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _resourcePersonController =
      TextEditingController();
  final TextEditingController _forwardThroughController =
      TextEditingController();
  final TextEditingController _pickupLocationController =
      TextEditingController();
  final TextEditingController _dropLocationController =
      TextEditingController();

  // Dropdown values
  String? _selectedFacility;
  String? _selectedPersons;

  // Date and Time values
  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;
  DateTime? _dropDate;
  TimeOfDay? _dropTime;

  // Helpers
  Future<void> _selectDate(BuildContext context, bool isPickup) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        isPickup ? _pickupDate = picked : _dropDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isPickup) async {
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());

    if (picked != null) {
      setState(() {
        isPickup ? _pickupTime = picked : _dropTime = picked;
      });
    }
  }

  String _formatDate(DateTime? date) =>
      date != null ? "${date.day}/${date.month}/${date.year}" : '';

  String _formatTime(TimeOfDay? time) =>
      time != null ? time.format(context) : '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue.shade700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/TCE.png'),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'TCE Cab Booking',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('View My Bookings'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('View Calendar'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.blue,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 15,
              backgroundImage: AssetImage('assets/TCE.png'),
            ),
            const SizedBox(width: 10),
            const Text('TCE Cab Booking',
                style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      backgroundColor: Colors.blue.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to TCE Cab Booking, ${widget.facultyName}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // Event Details Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Event Details',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Choose Facility
                    DropdownButtonFormField<String>(
                      value: _selectedFacility,
                      items: ['Vehicle', 'Van', 'Bus']
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedFacility = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Choose Facility',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _eventNameController,
                      decoration: const InputDecoration(
                        labelText: 'Event Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _resourcePersonController,
                      decoration: const InputDecoration(
                        labelText: 'Resource Person Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _forwardThroughController,
                      decoration: const InputDecoration(
                        labelText: 'Forward Through',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Vehicle Booking Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vehicle Booking',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _pickupLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _dropLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Drop Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: () => _selectDate(context, true),
                            decoration: InputDecoration(
                              labelText: 'Pickup Date',
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.calendar_today),
                              hintText: 'Select date',
                              helperText: _formatDate(_pickupDate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: () => _selectTime(context, true),
                            decoration: InputDecoration(
                              labelText: 'Pickup Time',
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.access_time),
                              helperText: _formatTime(_pickupTime),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: () => _selectDate(context, false),
                            decoration: InputDecoration(
                              labelText: 'Drop Date',
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.calendar_today),
                              helperText: _formatDate(_dropDate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: () => _selectTime(context, false),
                            decoration: InputDecoration(
                              labelText: 'Drop Time',
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.access_time),
                              helperText: _formatTime(_dropTime),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedPersons,
                      items: List.generate(
                          10,
                          (index) => DropdownMenuItem(
                                value: '${index + 1}',
                                child: Text('${index + 1}'),
                              )),
                      onChanged: (value) {
                        setState(() => _selectedPersons = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Number of Persons',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implement submission logic
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking Submitted')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Submit Booking',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
