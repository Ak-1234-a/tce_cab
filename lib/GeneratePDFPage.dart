import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class GeneratePDFPage extends StatelessWidget {
  const GeneratePDFPage({super.key});

  Future<Uint8List> _createPdf() async {
    final pdf = pw.Document();

    QuerySnapshot snapshot;
    try {
      snapshot = await FirebaseFirestore.instance.collection('bookings').get();
    } catch (e) {
      print('Error fetching Firestore data: $e');
      rethrow;
    }

    // Group bookings by department field
    Map<String, List<Map<String, dynamic>>> deptWise = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dept = data['department'] ?? 'Unknown Department';
      deptWise.putIfAbsent(dept, () => []).add(data);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
        ),
        build: (context) {
          List<pw.Widget> content = [
            pw.Header(
              level: 0,
              child: pw.Text("TCE Cab Booking Report (Department-wise)",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            )
          ];

          deptWise.forEach((dept, bookings) {
            content.add(pw.SizedBox(height: 20));
            content.add(pw.Text(
              "$dept (${bookings.length} events)",
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ));
            content.add(pw.SizedBox(height: 10));

            content.add(pw.Table.fromTextArray(
              headers: [
                'Event Name',
                'Vehicle Type',
                'Pickup Details',
                'Drop Details',
                'Faculty Email',
                'Status',
                'Rejection Reason'
              ],
              data: bookings.map((d) {
                return [
                  d['eventName'] ?? '-',
                  d['facility'] ?? '-',
                  '${d['pickupDate']} ${d['pickupTime']}\n${d['pickupLocation']}',
                  '${d['dropDate']} ${d['dropTime']}\n${d['dropLocation']}',
                  d['facultyEmail'] ?? '-',
                  d['status'] ?? '-',
                  d['status'] == 'rejected' ? (d['rejectionReason'] ?? '-') : '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(2.5),
                4: const pw.FlexColumnWidth(2.5),
                5: const pw.FlexColumnWidth(1.5),
                6: const pw.FlexColumnWidth(2),
              },
            ));
          });

          return content;
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TCE Cab Report')),
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
