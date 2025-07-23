import 'package:flutter/material.dart';
import 'GeneratePDFPage.dart';

class ReportSchedulePage extends StatefulWidget {
  const ReportSchedulePage({super.key});

  @override
  State<ReportSchedulePage> createState() => _ReportSchedulePageState();
}

class _ReportSchedulePageState extends State<ReportSchedulePage> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  final Color primaryColor = Colors.blue;

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => selectedDate = date);
  }

  void _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) setState(() => selectedTime = time);
  }

  void _generatePDF() {
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeneratePDFPage(
          selectedDate: selectedDate!,
          selectedTime: selectedTime!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Schedule Report"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 3,
              child: ListTile(
                leading: Icon(Icons.date_range, color: primaryColor),
                title: Text(
                  selectedDate == null
                      ? 'Select Date'
                      : '${selectedDate!.toLocal()}'.split(' ')[0],
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 15),
            Card(
              elevation: 3,
              child: ListTile(
                leading: Icon(Icons.access_time, color: primaryColor),
                title: Text(
                  selectedTime == null
                      ? 'Select Time'
                      : selectedTime!.format(context),
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: _pickTime,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _generatePDF,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Generate PDF Now"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
