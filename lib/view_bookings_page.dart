import 'package:flutter/material.dart';

class ViewBookingsPage extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;

  const ViewBookingsPage({super.key, required this.bookings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.blue,
      ),
      backgroundColor: Colors.blue.shade50,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final b = bookings[index];
          final isAccepted = b['status'] == 'Accepted';
          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        b['eventName'] ?? '',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (!isAccepted && b['rejectionReason'] != null) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Rejection Reason'),
                                content: Text(b['rejectionReason']),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  )
                                ],
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAccepted
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isAccepted ? 'Accepted' : 'Rejected',
                            style: TextStyle(
                              color: isAccepted
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.event, b['facility'], 'Facility'),
                  _buildInfoRow(Icons.person, b['resourcePerson'], 'Resource'),
                  _buildInfoRow(Icons.my_location, b['pickupLocation'], 'Pickup'),
                  _buildInfoRow(Icons.location_on, b['dropLocation'], 'Drop'),
                  _buildInfoRow(Icons.calendar_today,
                      '${b['pickupDate']} ${b['pickupTime']}', 'Pickup Time'),
                  _buildInfoRow(Icons.calendar_today,
                      '${b['dropDate']} ${b['dropTime']}', 'Drop Time'),
                  _buildInfoRow(Icons.group, b['numberOfPersons'], 'Persons'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String? text, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text('$label: ${text ?? ''}')),
        ],
      ),
    );
  }
}
