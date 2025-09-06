import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class GenerateExcelPage extends StatefulWidget {
  const GenerateExcelPage({super.key});

  @override
  State<GenerateExcelPage> createState() => _GenerateExcelPageState();
}

class _GenerateExcelPageState extends State<GenerateExcelPage> {
  bool _isGenerating = false;
  String _statusMessage = '';
  String? _filePath;
  bool _isEndOfMonth = false;

  @override
  void initState() {
    super.initState();
    _checkIsEndOfMonth();
  }

  // A simple function to check if the current date is the last day of the month.
  void _checkIsEndOfMonth() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    setState(() {
      _isEndOfMonth = now.month != tomorrow.month;
      if (!_isEndOfMonth) {
        _statusMessage = 'You can only generate the monthly report on the last day of the month.';
      } else {
        _statusMessage = 'It\'s the end of the month! Click "Generate Report" to create a monthly report.';
      }
    });
  }

  // Helper method to generate the Excel file from a list of documents
  Future<void> _createExcelFile(List<QueryDocumentSnapshot> docs) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Trip Report'];

      // Add headers
      sheetObject.appendRow([
        'Event Name',
        'Facility',
        'Pickup Date',
        'Pickup Time',
        'Pickup From',
        'Pickup To',
        'Trip Type',
        'Number of Persons',
        'Status',
        'Faculty Email',
      ]);

      // Add data rows
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        sheetObject.appendRow([
          data['eventName'] ?? 'N/A',
          data['facility'] ?? 'N/A',
          data['pickupDate'] ?? 'N/A',
          data['pickupTime'] ?? 'N/A',
          data['pickupFrom'] ?? 'N/A',
          data['pickupTo'] ?? 'N/A',
          data['tripType'] ?? 'N/A',
          data['numberOfPersons']?.toString() ?? 'N/A',
          data['status'] ?? 'N/A',
          data['facultyEmail'] ?? 'N/A',
        ]);
      }
      
      // Save the file to a temporary directory
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/monthly_trip_report.xlsx';
      final file = File(path);
      await file.writeAsBytes(excel.save()!);
      
      setState(() {
        _filePath = path;
        _statusMessage = 'Monthly report generated successfully. Click "Share Report" to open the sharing dialog.';
      });
    } catch (e) {
      debugPrint("Error creating Excel: $e");
      setState(() {
        _statusMessage = 'Error: Failed to generate report. ${e.toString()}';
      });
    }
  }

  // Generates a report for the current month
  Future<void> _generateMonthlyReport() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Fetching monthly data and generating Excel file...';
    });

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('new_bookings').get();
      
      // Get the first day of the current month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      // Filter documents based on pickupDate
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final pickupDateString = data['pickupDate'];
        if (pickupDateString != null) {
          try {
            final DateFormat format = DateFormat('d/M/yyyy');
            final pickupDate = format.parse(pickupDateString);
            return pickupDate.isAfter(firstDayOfMonth) || pickupDate.isAtSameMomentAs(firstDayOfMonth);
          } catch (e) {
            debugPrint("Error parsing date: $pickupDateString, Error: $e");
            return false;
          }
        }
        return false;
      }).toList();

      await _createExcelFile(filteredDocs);

    } catch (e) {
      debugPrint("Error fetching data for monthly report: $e");
      setState(() {
        _statusMessage = 'Error: Failed to fetch data. ${e.toString()}';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _shareReport() async {
    if (_filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please generate a report first.')),
        );
      }
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(_filePath!)],
        subject: 'Monthly Trip Report',
        text: 'Please find the attached monthly trip report.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share file: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Excel Report'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isGenerating
                ? const CircularProgressIndicator()
                : Icon(_isEndOfMonth ? Icons.check_circle_outline : Icons.calendar_month, color: _isEndOfMonth ? Colors.green : Colors.grey, size: 80),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _isEndOfMonth ? _generateMonthlyReport : null,
                icon: const Icon(Icons.analytics),
                label: const Text('Generate Monthly Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEndOfMonth ? Colors.blue : Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_filePath != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _shareReport,
                  icon: const Icon(Icons.share),
                  label: const Text('Share Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}