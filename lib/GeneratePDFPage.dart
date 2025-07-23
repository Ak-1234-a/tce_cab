import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class GeneratePDFPage extends StatelessWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;

  const GeneratePDFPage({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
  });

  Future<Uint8List> _createPdf() async {
    final pdf = pw.Document();

    final monthStart = DateTime(selectedDate.year, selectedDate.month, 1);
    final monthEnd = DateTime(selectedDate.year, selectedDate.month + 1, 1).subtract(const Duration(seconds: 1));

    QuerySnapshot snapshot;
    try {
      snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('timestamp', isGreaterThanOrEqualTo: monthStart)
          .where('timestamp', isLessThanOrEqualTo: monthEnd)
          .get();
    } catch (e) {
      print('Error fetching Firestore data: $e');
      rethrow;
    }

    // Separate bookings in Dart (no need for composite index)
    final accepted = snapshot.docs.where((doc) => doc['status'] == 'accepted').toList();
    final rejected = snapshot.docs.where((doc) => doc['status'] == 'rejected').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              "Vehicle Booking Monthly Report - ${DateFormat('MMMM yyyy').format(selectedDate)}",
              style: pw.TextStyle(fontSize: 20),
            ),
          ),

          pw.Text("ACCEPTED REQUESTS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (accepted.isEmpty)
            pw.Text("No accepted requests found."),
          ...accepted.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return pw.Bullet(
              text:
              "${data['eventName'] ?? 'No Event'} by ${data['facultyEmail'] ?? 'Unknown'} on ${_formatDate(data['pickupDate'])} at ${data['pickupTime'] ?? 'N/A'}",
            );
          }),

          pw.SizedBox(height: 20),

          pw.Text("REJECTED REQUESTS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (rejected.isEmpty)
            pw.Text("No rejected requests found."),
          ...rejected.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return pw.Bullet(
              text:
              "${data['eventName'] ?? 'No Event'} by ${data['facultyEmail'] ?? 'Unknown'} on ${_formatDate(data['pickupDate'])} at ${data['pickupTime'] ?? 'N/A'}. Reason: ${data['rejectionReason'] ?? 'N/A'}",
            );
          }),
        ],
      ),
    );

    return pdf.save();
  }

  static String _formatDate(dynamic date) {
    if (date is Timestamp) {
      return DateFormat('dd MMM yyyy').format(date.toDate());
    } else if (date is String) {
      return date;
    } else {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Preview')),
      body: FutureBuilder<Uint8List>(
        future: _createPdf(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error generating PDF: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data found.'));
          }

          return PdfPreview(
            build: (format) => Future.value(snapshot.data!),
          );
        },
      ),
    );
  }
}
