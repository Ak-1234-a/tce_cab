import 'package:flutter/material.dart';
import 'GeneratePDFPage.dart';

class ReportSchedulePage extends StatelessWidget {
  const ReportSchedulePage({super.key});

  final Color primaryColor = Colors.blue;

  void _generatePDF(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GeneratePDFPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Department-wise Report"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 100, color: primaryColor),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => _generatePDF(context),
              icon: const Icon(Icons.analytics),
              label: const Text("Generate Report Now"),
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
