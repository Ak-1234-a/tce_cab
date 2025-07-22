import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<Map<String, String>>> _events = {};

  List<Map<String, String>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _processSnapshot(QuerySnapshot snapshot) {
    final newEvents = <DateTime, List<Map<String, String>>>{};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      final pickupDateStr = data['pickupDate'] as String? ?? '';
      final parts = pickupDateStr.split('/');
      if (parts.length != 3) continue;

      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);

      if (day == null || month == null || year == null) continue;

      final eventDate = DateTime(year, month, day);

      final eventInfo = <String, String>{
        'eventName': data['eventName'] ?? '',
        'facility': data['facility'] ?? '',
        'pickupLocation': data['pickupLocation'] ?? '',
        'dropLocation': data['dropLocation'] ?? '',
        'pickupTime': data['pickupTime'] ?? '',
        'dropTime': data['dropTime'] ?? '',
        'numberOfPersons': data['numberOfPersons'] ?? '',
        'status': data['status'] ?? '',
      };

      newEvents[eventDate] = (newEvents[eventDate] ?? [])..add(eventInfo);
    }

    // Compare maps before calling setState
    if (newEvents.toString() != _events.toString()) {
      setState(() {
        _events = newEvents;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Event Calendar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 3,
      ),
      backgroundColor: Colors.blue.shade50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .orderBy('pickupDate')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading events', style: GoogleFonts.poppins()));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // SAFELY update _events using post-frame callback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _processSnapshot(snapshot.data!);
          });

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TableCalendar<Map<String, String>>(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2100),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getEventsForDay,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.blue.shade200,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    defaultTextStyle: GoogleFonts.poppins(color: Colors.blue.shade900),
                    weekendTextStyle: GoogleFonts.poppins(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedTextStyle: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    todayTextStyle: GoogleFonts.poppins(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  headerStyle: HeaderStyle(
                    titleTextStyle: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                    formatButtonVisible: false,
                    leftChevronIcon: Icon(Icons.chevron_left, color: Colors.blue.shade700),
                    rightChevronIcon: Icon(Icons.chevron_right, color: Colors.blue.shade700),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildEventList())
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventList() {
    if (_selectedDay == null) {
      return Center(
        child: Text(
          'Select a date to see events',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.blue.shade700),
        ),
      );
    }

    final events = _getEventsForDay(_selectedDay!);

    if (events.isEmpty) {
      return Center(
        child: Text(
          'No events on this day',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.blue.shade700),
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (_, index) {
        final ev = events[index];
        final status = ev['status'] ?? '';

        Color statusColor = Colors.green.shade700;
        if (status.toLowerCase() == 'pending') {
          statusColor = Colors.orange.shade700;
        } else if (status.toLowerCase() == 'rejected') {
          statusColor = Colors.red.shade700;
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 3,
          shadowColor: Colors.blue.shade100,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Icon(Icons.event, color: Colors.blue.shade700, size: 28),
            title: Text(
              ev['eventName'] ?? '',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.blue.shade900,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Facility: ${ev['facility']}\n'
                'From: ${ev['pickupLocation']} at ${ev['pickupTime']}\n'
                'To: ${ev['dropLocation']} at ${ev['dropTime']}\n'
                'Persons: ${ev['numberOfPersons']}',
                style: GoogleFonts.poppins(color: Colors.blue.shade800, fontSize: 13, height: 1.3),
              ),
            ),
            trailing: Text(
              status,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: statusColor,
              ),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
