import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final outDir = Directory('build/sample_pdfs');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  await _buildMainQuotation(outDir);
  await _buildSupplyQuotation(outDir);
  await _buildSupplyPaginationSample(outDir);
  await _buildLetterheadMeasurementSheet(outDir);

  stdout.writeln('Generated sample PDFs in ${outDir.path}');
}

Future<void> _buildMainQuotation(Directory outDir) async {
  final pdf = pw.Document();
  final navy = PdfColor.fromHex('#1A3A5C');
  final amber = PdfColor.fromHex('#F5A623');
  final letterheadImage = pw.MemoryImage(await _loadLetterheadBytes());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 104, 36, 36),
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        buildBackground: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Image(letterheadImage, fit: pw.BoxFit.fill),
        ),
      ),
      build: (_) => [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Date : 15/4/2026',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Client Name : Sample Client',
            style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Subject : Construction Quotation',
            style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Project : Residential House',
            style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Location : Rawalpindi',
            style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(
            color: const PdfColor(0.10, 0.23, 0.36, 0.08),
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(
              color: const PdfColor(0.10, 0.23, 0.36, 0.18),
              width: 0.6,
            ),
          ),
          child: pw.Text(
            'Sample description shown below location in low-opacity box.',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          color: navy,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(
            'COST ESTIMATE',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Description', 'Qty', 'Unit', 'Rate (PKR)', 'Amount'],
          data: [
            ['Cement', '300', 'Bags', '1450', '435000'],
            ['Steel', '2500', 'Kg', '290', '725000'],
            ['Sand', '1800', 'Cft', '110', '198000'],
          ],
          headerStyle: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: navy),
          cellStyle: const pw.TextStyle(fontSize: 10.5),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          color: navy,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TOTAL ESTIMATED COST',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                '1.36 Million PKR',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: amber,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final file = File('${outDir.path}/sample_main_quotation.pdf');
  await file.writeAsBytes(await pdf.save());
}

Future<void> _buildSupplyQuotation(Directory outDir) async {
  final pdf = pw.Document();
  final navy = PdfColor.fromHex('#1A3A5C');
  final amber = PdfColor.fromHex('#F5A623');
  final letterheadImage = pw.MemoryImage(await _loadLetterheadBytes());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(18, 108, 18, 36),
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        buildBackground: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Image(letterheadImage, fit: pw.BoxFit.fill),
        ),
      ),
      build: (_) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'SUPPLY QUOTATION',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: navy,
              ),
            ),
            pw.Text(
              'Date : 15/4/2026',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text('To : Sample Client',
            style: const pw.TextStyle(fontSize: 11.5)),
        pw.Text('Subject : Supply of Building Material',
            style: const pw.TextStyle(fontSize: 11.5)),
        pw.Text('Delivery Location : Islamabad',
            style: const pw.TextStyle(fontSize: 11.5)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Description', 'Unit', 'Qty', 'Rate', 'Amount'],
          data: [
            ['Cement OPC', 'Bag', '500', '1450', '725000'],
            ['Steel 60 Grade', 'Kg', '3500', '290', '1015000'],
            ['Crush', 'Cft', '2200', '105', '231000'],
          ],
          headerStyle: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: navy),
          cellStyle: const pw.TextStyle(fontSize: 10.5),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          color: navy,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'GRAND TOTAL',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                '1.971 Million PKR',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: amber,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final file = File('${outDir.path}/sample_supply_quotation.pdf');
  await file.writeAsBytes(await pdf.save());
}

Future<void> _buildSupplyPaginationSample(Directory outDir) async {
  final pdf = pw.Document();
  final navy = PdfColor.fromHex('#1A3A5C');
  final amber = PdfColor.fromHex('#F5A623');
  final letterheadImage = pw.MemoryImage(await _loadLetterheadBytes());

  final items = List.generate(
    40,
    (index) => [
      'Item ${index + 1}',
      'Unit',
      '${index + 1}',
      '100',
      '${(index + 1) * 100}',
    ],
  );

  const itemsPerPage = 30;
  for (var start = 0; start < items.length; start += itemsPerPage) {
    final end = (start + itemsPerPage < items.length)
        ? start + itemsPerPage
        : items.length;
    final isLastPage = end == items.length;

    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.zero,
        pageFormat: PdfPageFormat.a4,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(letterheadImage, fit: pw.BoxFit.fill),
          ),
        ),
        build: (_) {
          final pageItems = items.sublist(start, end);
          final table = pw.TableHelper.fromTextArray(
            headers: ['Description', 'Unit', 'Qty', 'Rate', 'Amount'],
            data: pageItems,
            headerStyle: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: navy),
            cellStyle: const pw.TextStyle(fontSize: 10.5),
          );

          return pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(18, 108, 18, 36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'SUPPLY QUOTATION',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    pw.Text(
                      'Date : 18/4/2026',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text('To : Sample Client',
                    style: const pw.TextStyle(fontSize: 11.5)),
                pw.Text('Subject : Supply Pagination Test',
                    style: const pw.TextStyle(fontSize: 11.5)),
                pw.SizedBox(height: 10),
                table,
                if (isLastPage) ...[
                  pw.SizedBox(height: 12),
                  pw.Container(
                    color: navy,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'GRAND TOTAL',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          '4.100 Million PKR',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Looking forward for your positive response and we hope that this is the start of a faithful working relationship between us.',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'In case of confirmation of order 80% will be advance.',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Thank You,'),
                        pw.Text('Ajmal Khan Jadoon,'),
                        pw.Text('CEO'),
                        pw.Text('Friend & Friends International'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  final file = File('${outDir.path}/sample_supply_pagination_40_items.pdf');
  await file.writeAsBytes(await pdf.save());
}

Future<void> _buildLetterheadMeasurementSheet(Directory outDir) async {
  final pdf = pw.Document();
  final navy = PdfColor.fromHex('#1A3A5C');
  final letterheadImage = pw.MemoryImage(await _loadLetterheadBytes());

  final grid = pw.Table(
    border: pw.TableBorder.all(color: navy, width: 0.9),
    columnWidths: const {
      0: pw.FixedColumnWidth(34),
      1: pw.FixedColumnWidth(88),
      2: pw.FixedColumnWidth(88),
      3: pw.FixedColumnWidth(88),
    },
    children: [
      pw.TableRow(
        children: [
          _cellHeader('', navy),
          _cellHeader('A', navy),
          _cellHeader('B', navy),
          _cellHeader('C', navy),
        ],
      ),
      pw.TableRow(
        children: [
          _cellHeader('1', navy),
          _blankCell(),
          _blankCell(),
          _blankCell(),
        ],
      ),
      pw.TableRow(
        children: [
          _cellHeader('2', navy),
          _blankCell(),
          _blankCell(),
          _blankCell(),
        ],
      ),
      pw.TableRow(
        children: [
          _cellHeader('3', navy),
          _blankCell(),
          _blankCell(),
          _blankCell(),
        ],
      ),
    ],
  );

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        buildBackground: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Image(letterheadImage, fit: pw.BoxFit.fill),
        ),
      ),
      build: (_) => pw.Stack(
        children: [
          pw.Positioned(
            left: 18,
            top: 108,
            child: grid,
          ),
          pw.Positioned(
            left: 18,
            top: 68,
            child: pw.Text(
              'Letterhead Placement Grid',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: navy,
              ),
            ),
          ),
          pw.Positioned(
            left: 18,
            top: 108 + 4 * 34 + 12,
            child: pw.Text(
              'Tell me the start cell and end cell, for example A1 to C3.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    ),
  );

  final file = File('${outDir.path}/sample_letterhead_measurement_sheet.pdf');
  await file.writeAsBytes(await pdf.save());
}

pw.Widget _cellHeader(String text, PdfColor navy) {
  return pw.Container(
    height: 30,
    alignment: pw.Alignment.center,
    color: const PdfColor(1, 1, 1, 0.18),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: navy,
      ),
    ),
  );
}

pw.Widget _blankCell() {
  return pw.Container(
    height: 34,
    color: const PdfColor(1, 1, 1, 0.08),
  );
}

Future<Uint8List> _loadLetterheadBytes() async {
  final file = File('assets/letterhead.png');
  if (!file.existsSync()) {
    throw StateError('Missing assets/letterhead.png');
  }
  return Uint8List.fromList(file.readAsBytesSync());
}
