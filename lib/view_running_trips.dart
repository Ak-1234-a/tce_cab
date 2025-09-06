import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ViewRunningTripsPage extends StatefulWidget {
  const ViewRunningTripsPage({super.key});

  @override
  State<ViewRunningTripsPage> createState() => _ViewRunningTripsPageState();
}

class _ViewRunningTripsPageState extends State<ViewRunningTripsPage> {
  // Function to mark a trip as completed and update the new_bookings status
  Future<void> _markAsCompleted(String driverDocId, String bookingId, String tripType, String vehicleId) async {
    try {
      final driverRef = FirebaseFirestore.instance.collection('new_drivers').doc(driverDocId);
      final vehicleRef = FirebaseFirestore.instance.collection('new_vehicles').doc(vehicleId);
      final bookingRef = FirebaseFirestore.instance.collection('new_bookings').doc(bookingId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Fetch the latest state of the documents within the transaction
        final driverDoc = await transaction.get(driverRef);
        final vehicleDoc = await transaction.get(vehicleRef);

        if (!driverDoc.exists || !vehicleDoc.exists) {
          throw Exception("Driver or Vehicle document not found.");
        }

        final driverData = driverDoc.data() as Map<String, dynamic>;
        final vehicleData = vehicleDoc.data() as Map<String, dynamic>;

        // Remove the booking from the driver's list
        if (driverData.containsKey('${tripType}_bookings')) {
          List<dynamic> driverBookings = List.from(driverData['${tripType}_bookings']);
          final updatedDriverBookings = driverBookings.where((booking) => booking['bookingId'] != bookingId).toList();
          transaction.update(driverRef, {'${tripType}_bookings': updatedDriverBookings});
        }

        // Remove the booking from the vehicle's list
        if (vehicleData.containsKey('${tripType}_bookings')) {
          List<dynamic> vehicleBookings = List.from(vehicleData['${tripType}_bookings']);
          final updatedVehicleBookings = vehicleBookings.where((booking) => booking['bookingId'] != bookingId).toList();
          transaction.update(vehicleRef, {'${tripType}_bookings': updatedVehicleBookings});
        }

        // Update the new_bookings document with the 'Completed' status
        if (tripType == 'pickup') {
          transaction.update(bookingRef, {'pickupTripStatus': 'Completed'});
        } else if (tripType == 'drop') {
          // The image shows 'dropTipStatus' so that's what's used here.
          transaction.update(bookingRef, {'dropTripStatus': 'Completed'});
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip marked as completed and entries removed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark trip as completed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Running Trips',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('new_bookings').snapshots(), // Stream from new_bookings
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No running trips found.',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            );
          }

          final runningTrips = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final pickupStatus = data['pickupTripStatus'] ?? '';
            final dropStatus = data['dropTipStatus'] ?? '';
            final isPickupAccepted = data['pickup_status'] == 'accepted';
            final isDropAccepted = data['drop_status'] == 'accepted';

            // Check if a pickup trip is "running"
            bool isPickupRunning = isPickupAccepted && pickupStatus != 'Completed' && _isTripStarted(data['pickupDate'], data['pickupTime']);

            // Check if a drop trip is "running" (and is a round trip)
            bool isDropRunning = (data['tripType'] == 'Round Trip') && isDropAccepted && dropStatus != 'Completed' && _isTripStarted(data['dropDate'], data['dropTime']);
            
            return isPickupRunning || isDropRunning;
          }).toList();

          if (runningTrips.isEmpty) {
            return Center(
              child: Text(
                'No running trips found.',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: runningTrips.length,
            itemBuilder: (context, index) {
              final doc = runningTrips[index];
              final data = doc.data() as Map<String, dynamic>;
              final String? pickupVehicleId = data['pickup_vehicleId'];
              final String? dropVehicleId = data['drop_vehicleId'];
              final String? pickupDriverId = data['pickup_driverId'];
              final String? dropDriverId = data['drop_driverId'];
              
              String tripType = 'Unknown';
              String driverId = 'N/A';
              String vehicleId = 'N/A';
              String status = 'N/A';

              // Determine which trip (pickup or drop) is currently running
              final isPickupRunning = (data['pickup_status'] == 'accepted') && (data['pickupTripStatus'] != 'Completed' || data['pickupTripStatus'] == null) && _isTripStarted(data['pickupDate'], data['pickupTime']);
              final isDropRunning = (data['tripType'] == 'Round Trip') && (data['drop_status'] == 'accepted') && (data['dropTipStatus'] != 'Completed' || data['dropTipStatus'] == null) && _isTripStarted(data['dropDate'], data['dropTime']);

              if (isPickupRunning) {
                tripType = 'Pickup';
                driverId = pickupDriverId ?? 'N/A';
                vehicleId = pickupVehicleId ?? 'N/A';
                status = data['pickupTripStatus'] ?? 'Started';
              } else if (isDropRunning) {
                tripType = 'Drop';
                driverId = dropDriverId ?? 'N/A';
                vehicleId = dropVehicleId ?? 'N/A';
                status = data['dropTipStatus'] ?? 'Started';
              }
              
              if (tripType == 'Unknown') {
                return const SizedBox.shrink();
              }

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Trip Type:', tripType),
                      const Divider(),
                      _buildInfoRow('Event Name:', data['eventName'] ?? 'N/A'),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('new_drivers').doc(driverId).get(),
                        builder: (context, driverSnapshot) {
                          if (driverSnapshot.connectionState == ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }
                          String driverName = 'N/A';
                          if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
                            driverName = (driverSnapshot.data!.data() as Map<String, dynamic>)['name'] ?? 'N/A';
                          }
                          return _buildInfoRow('Driver:', driverName);
                        },
                      ),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('new_vehicles').doc(vehicleId).get(),
                        builder: (context, vehicleSnapshot) {
                          if (vehicleSnapshot.connectionState == ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }
                          String vehicleInfo = 'N/A';
                          if (vehicleSnapshot.hasData && vehicleSnapshot.data!.exists) {
                            final vehicleData = vehicleSnapshot.data!.data() as Map<String, dynamic>;
                            vehicleInfo = '${vehicleData['name'] ?? 'N/A'} - ${vehicleData['numberPlate'] ?? 'N/A'}';
                          }
                          return _buildInfoRow('Vehicle:', vehicleInfo);
                        },
                      ),
                      _buildInfoRow('From:', data[tripType == 'Pickup' ? 'pickupFrom' : 'dropFrom'] ?? 'N/A'),
                      _buildInfoRow('To:', data[tripType == 'Pickup' ? 'pickupTo' : 'dropTo'] ?? 'N/A'),
                      _buildInfoRow('Date:', data[tripType == 'Pickup' ? 'pickupDate' : 'dropDate'] ?? 'N/A'),
                      _buildInfoRow('Time:', data[tripType == 'Pickup' ? 'pickupTime' : 'dropTime'] ?? 'N/A'),
                      _buildInfoRow('Status:', status),
                      const SizedBox(height: 12),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _showMarkAsCompletedDialog(
                            context,
                            driverId,
                            doc.id,
                            tripType.toLowerCase(),
                            vehicleId,
                          ),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                          label: Text('Mark as Completed', style: GoogleFonts.poppins(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Function to check if the trip's date and time have passed
  bool _isTripStarted(String date, String time) {
    try {
      final DateFormat dateFormat = DateFormat('d/M/yyyy h:mm a');
      final tripDateTime = dateFormat.parse('$date $time');
      final now = DateTime.now();
      return now.isAfter(tripDateTime);
    } catch (e) {
      // Handle parsing errors gracefully
      return false;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showMarkAsCompletedDialog(BuildContext context, String driverDocId, String bookingId, String tripType, String vehicleId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Completion'),
          content: const Text('Are you sure you want to mark this trip as completed? This action will remove the trip entry and free up the vehicle.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _markAsCompleted(driverDocId, bookingId, tripType, vehicleId);
                Navigator.of(context).pop();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }
}