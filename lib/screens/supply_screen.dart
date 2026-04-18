import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';

import 'pdf_preview_screen.dart';

// ─── Supply Item Model ────────────────────────────────────────────────────────

class SupplyItem {
  String id;
  final TextEditingController descCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController rateCtrl;

  SupplyItem({
    required this.id,
    String desc = '',
    String unit = 'Pcs',
    String qty = '1',
    String rate = '0',
  })  : descCtrl = TextEditingController(text: desc),
        unitCtrl = TextEditingController(text: unit),
        qtyCtrl = TextEditingController(text: qty),
        rateCtrl = TextEditingController(text: rate);

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get rate => double.tryParse(rateCtrl.text) ?? 0;
  double get amount => qty * rate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'desc': descCtrl.text,
        'unit': unitCtrl.text,
        'qty': qtyCtrl.text,
        'rate': rateCtrl.text,
      };

  void dispose() {
    descCtrl.dispose();
    unitCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class SupplyScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const SupplyScreen({super.key, this.initialData});

  @override
  State<SupplyScreen> createState() => _SupplyScreenState();
}

class _SupplyScreenState extends State<SupplyScreen> {
  String? _galleryId;

  final _toCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _termsCtrl = TextEditingController(
      text: 'Payment: 80% advance on confirmation.\n'
          'Delivery within agreed timeline.\n'
          'Prices are exclusive of GST unless stated.');

  List<SupplyItem> _items = [];
  bool _applyTax = false;
  double _taxPct = 17.0;
  final _taxPctCtrl = TextEditingController(text: '17');

  // Editable labels
  String _labelTo = 'To';
  String _labelSubject = 'Subject / Supply of';
  String _labelRef = 'Reference No';
  String _labelLocation = 'Delivery Location';

  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _applyData(widget.initialData!);
    } else {
      _addItem();
      _checkSaved();
    }
    _taxPctCtrl.addListener(() =>
        setState(() => _taxPct = double.tryParse(_taxPctCtrl.text) ?? _taxPct));
  }

  void _applyData(Map<String, dynamic> d) {
    _galleryId = d['id'] as String?;
    _toCtrl.text = d['to'] ?? '';
    _subjectCtrl.text = d['subject'] ?? '';
    _refCtrl.text = d['ref'] ?? '';
    _locationCtrl.text = d['location'] ?? '';
    _termsCtrl.text = d['terms'] ?? _termsCtrl.text;
    _applyTax = d['applyTax'] ?? false;
    _taxPct = (d['taxPct'] as num?)?.toDouble() ?? 17.0;
    _taxPctCtrl.text = _taxPct.toStringAsFixed(0);
    _labelTo = d['labelTo'] ?? 'To';
    _labelSubject = d['labelSubject'] ?? 'Subject / Supply of';
    _labelRef = d['labelRef'] ?? 'Reference No';
    _labelLocation = d['labelLocation'] ?? 'Delivery Location';

    final rawItems = d['items'] as List? ?? [];
    _items = rawItems
        .map((e) => SupplyItem(
              id: e['id'] ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
              desc: e['desc'] ?? '',
              unit: e['unit'] ?? 'Pcs',
              qty: e['qty'] ?? '1',
              rate: e['rate'] ?? '0',
            ))
        .toList();

    if (_items.isEmpty) _addItem();
  }

  Future<void> _checkSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('supply_gallery_v1');
    if (raw != null) {
      try {
        if ((jsonDecode(raw) as List).isNotEmpty && mounted) {
          setState(() => _hasSaved = true);
        }
      } catch (_) {}
    }
  }

  void _addItem() {
    setState(() => _items.add(
          SupplyItem(id: 'item_${DateTime.now().millisecondsSinceEpoch}'),
        ));
  }

  void _removeItem(int i) {
    if (_items.length <= 1) {
      _showSnack('At least one item is required');
      return;
    }
    setState(() => _items[i].dispose());
    setState(() => _items.removeAt(i));
  }

  double get _subtotal => _items.fold(0.0, (s, i) => s + i.amount);
  double get _taxAmount => _applyTax ? _subtotal * (_taxPct / 100) : 0.0;
  double get _grandTotal => _subtotal + _taxAmount;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  List<pw.InlineSpan> _buildPdfFormattedSpans(String input,
      {double fontSize = 9.5,
      PdfColor color = PdfColors.black,
      pw.FontWeight? fontWeight,
      pw.FontStyle? fontStyle,
      pw.TextDecoration? decoration}) {
    final spans = <pw.InlineSpan>[];
    final baseStyle = pw.TextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
    );
    if (input.isEmpty) {
      spans.add(pw.TextSpan(text: '', style: baseStyle));
      return spans;
    }

    final pattern = RegExp(r'(__[^_\n]+__|\*[^*\n]+\*|_[^_\n]+_|~[^~\n]+~)');
    var cursor = 0;
    for (final m in pattern.allMatches(input)) {
      if (m.start > cursor) {
        spans.add(pw.TextSpan(
            text: input.substring(cursor, m.start), style: baseStyle));
      }

      final token = m.group(0)!;
      String text = token;
      var style = baseStyle;

      if (token.startsWith('__') && token.endsWith('__') && token.length > 4) {
        text = token.substring(2, token.length - 2);
        style = style.copyWith(decoration: pw.TextDecoration.underline);
      } else if (token.startsWith('*') &&
          token.endsWith('*') &&
          token.length > 2) {
        text = token.substring(1, token.length - 1);
        style = style.copyWith(fontWeight: pw.FontWeight.bold);
      } else if (token.startsWith('_') &&
          token.endsWith('_') &&
          token.length > 2) {
        text = token.substring(1, token.length - 1);
        style = style.copyWith(fontStyle: pw.FontStyle.italic);
      } else if (token.startsWith('~') &&
          token.endsWith('~') &&
          token.length > 2) {
        text = token.substring(1, token.length - 1);
        style = style.copyWith(decoration: pw.TextDecoration.lineThrough);
      }

      spans.add(pw.TextSpan(text: text, style: style));
      cursor = m.end;
    }

    if (cursor < input.length) {
      spans.add(pw.TextSpan(text: input.substring(cursor), style: baseStyle));
    }

    return spans;
  }

  pw.Widget _buildPdfFormattedText(String input,
      {double fontSize = 9.5,
      PdfColor color = PdfColors.black,
      pw.FontWeight? fontWeight,
      pw.FontStyle? fontStyle,
      pw.TextDecoration? decoration,
      pw.TextAlign textAlign = pw.TextAlign.left}) {
    return pw.RichText(
      textAlign: textAlign,
      text: pw.TextSpan(
        children: _buildPdfFormattedSpans(
          input,
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          decoration: decoration,
        ),
      ),
    );
  }

  Map<String, dynamic> _buildDataMap() => {
        'id': _galleryId ?? 'sup_${DateTime.now().millisecondsSinceEpoch}',
        'to': _toCtrl.text,
        'subject': _subjectCtrl.text,
        'ref': _refCtrl.text,
        'location': _locationCtrl.text,
        'terms': _termsCtrl.text,
        'applyTax': _applyTax,
        'taxPct': _taxPct,
        'labelTo': _labelTo,
        'labelSubject': _labelSubject,
        'labelRef': _labelRef,
        'labelLocation': _labelLocation,
        'items': _items.map((i) => i.toJson()).toList(),
        'subtotal': _subtotal,
        'grandTotal': _grandTotal,
        'savedAt': DateTime.now().toIso8601String(),
      };

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _buildDataMap();
    _galleryId ??= data['id'] as String;
    data['id'] = _galleryId!;

    List<dynamic> gallery = [];
    final raw = prefs.getString('supply_gallery_v1');
    if (raw != null) {
      try {
        gallery = jsonDecode(raw) as List;
      } catch (_) {}
    }

    final idx = gallery.indexWhere((p) => p['id'] == _galleryId);
    if (idx >= 0) {
      gallery[idx] = data;
    } else {
      gallery.insert(0, data);
    }

    await prefs.setString('supply_gallery_v1', jsonEncode(gallery));
    if (mounted) {
      setState(() => _hasSaved = true);
      _showSnack('Supply order saved');
    }
  }

  Future<void> _loadLast() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('supply_gallery_v1');
    if (raw == null) {
      _showSnack('No saved orders found');
      return;
    }
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        _showSnack('No saved orders found');
        return;
      }
      list.sort((a, b) {
        final ad = DateTime.tryParse(a['savedAt'] ?? '') ?? DateTime(2000);
        final bd = DateTime.tryParse(b['savedAt'] ?? '') ?? DateTime(2000);
        return bd.compareTo(ad);
      });
      setState(() => _applyData(list.first));
      _showSnack('Last supply order loaded');
    } catch (_) {
      _showSnack('Failed to load');
    }
  }

  // ── PDF ───────────────────────────────────────────────────────────────────

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final bgData = await _loadLetterheadData();
    final bgImage = pw.MemoryImage(bgData.buffer.asUint8List());
    final navyColor = PdfColor.fromHex('#1A3A5C');
    final amberColor = PdfColor.fromHex('#F5A623');
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    const itemsPerPage = 33;
    for (var start = 0; start < _items.length; start += itemsPerPage) {
      final end = (start + itemsPerPage < _items.length)
          ? start + itemsPerPage
          : _items.length;
      final isLastPage = end == _items.length;
      final pageBottom = isLastPage ? 20.0 : 8.0;

      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Stack(children: [
            pw.Positioned(
                left: 0,
                top: 0,
                right: 0,
                bottom: 0,
                child: pw.Image(bgImage, fit: pw.BoxFit.fill)),
            pw.Positioned(
                top: 124,
                left: 18,
                right: 18,
                bottom: pageBottom,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: _buildPdfContent(navyColor, amberColor, dateStr,
                        pageItems: _items.sublist(start, end),
                        isLastPage: isLastPage))),
          ]),
        ),
      );
    }

    return pdf.save();
  }

  Future<ByteData> _loadLetterheadData() async {
    try {
      return await rootBundle.load('assets/letterhead.png');
    } catch (_) {
      return rootBundle.load('assets/letterhead.jpg');
    }
  }

  Future<void> _generatePdf() async {
    try {
      _showSnack('Generating PDF…');
      final bytes = await _buildPdfBytes();
      final toName = _toCtrl.text.isNotEmpty
          ? _toCtrl.text.replaceAll(' ', '_')
          : 'SupplyOrder';
      await Printing.sharePdf(bytes: bytes, filename: 'FnF_Supply_$toName.pdf');
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _previewPdf() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: 'Supply Quotation Preview',
          buildPdf: (_) => _buildPdfBytes(),
        ),
      ),
    );
  }

  List<pw.Widget> _buildPdfContent(
    PdfColor navyColor,
    PdfColor amberColor,
    String dateStr, {
    required List<SupplyItem> pageItems,
    required bool isLastPage,
  }) {
    final w = <pw.Widget>[];
    const bold = pw.FontWeight.bold;
    const ts8 = pw.TextStyle(fontSize: 9.5);
    const ts9 = pw.TextStyle(fontSize: 10.5);

    w.add(
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      _buildPdfFormattedText('SUPPLY QUOTATION',
          fontSize: 13, fontWeight: bold, color: navyColor),
      pw.Text('Date : $dateStr',
          style: pw.TextStyle(fontSize: 11, fontWeight: bold)),
    ]));
    w.add(pw.SizedBox(height: 1));

    if (_refCtrl.text.isNotEmpty) {
      w.add(pw.RichText(
          text: pw.TextSpan(children: [
        ..._buildPdfFormattedSpans('$_labelRef : ',
            fontSize: 10.5, fontWeight: bold),
        ..._buildPdfFormattedSpans(_refCtrl.text, fontSize: 10.5),
      ])));
    }
    if (_toCtrl.text.isNotEmpty) {
      w.add(pw.RichText(
          text: pw.TextSpan(children: [
        ..._buildPdfFormattedSpans('$_labelTo : ',
            fontSize: 10.5, fontWeight: bold),
        ..._buildPdfFormattedSpans(_toCtrl.text, fontSize: 10.5),
      ])));
    }
    if (_subjectCtrl.text.isNotEmpty) {
      w.add(pw.RichText(
          text: pw.TextSpan(children: [
        ..._buildPdfFormattedSpans('$_labelSubject : ',
            fontSize: 10.5, fontWeight: bold),
        ..._buildPdfFormattedSpans(_subjectCtrl.text, fontSize: 10.5),
      ])));
    }
    if (_locationCtrl.text.isNotEmpty) {
      w.add(pw.RichText(
          text: pw.TextSpan(children: [
        ..._buildPdfFormattedSpans('$_labelLocation : ',
            fontSize: 10.5, fontWeight: bold),
        ..._buildPdfFormattedSpans(_locationCtrl.text, fontSize: 10.5),
      ])));
    }
    w.add(pw.SizedBox(height: 2));

    // Items table with visible row/column grid lines.
    pw.Widget tableCell(pw.Widget child,
        {bool isHeader = false,
        PdfColor? bg,
        pw.Alignment alignment = pw.Alignment.centerLeft}) {
      return pw.Container(
        alignment: alignment,
        color: isHeader ? navyColor : bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: child,
      );
    }

    final itemTableRows = <pw.TableRow>[];
    itemTableRows.add(pw.TableRow(children: [
      tableCell(
          _buildPdfFormattedText('Description',
              fontSize: 9.2, fontWeight: bold, color: PdfColors.white),
          isHeader: true),
      tableCell(
          _buildPdfFormattedText('Unit',
              fontSize: 9.2, fontWeight: bold, color: PdfColors.white),
          isHeader: true),
      tableCell(
          _buildPdfFormattedText('Qty',
              fontSize: 9.2,
              fontWeight: bold,
              color: PdfColors.white,
              textAlign: pw.TextAlign.right),
          isHeader: true,
          alignment: pw.Alignment.centerRight),
      tableCell(
          _buildPdfFormattedText('Rate',
              fontSize: 9.2,
              fontWeight: bold,
              color: PdfColors.white,
              textAlign: pw.TextAlign.right),
          isHeader: true,
          alignment: pw.Alignment.centerRight),
      tableCell(
          _buildPdfFormattedText('Amount',
              fontSize: 9.2,
              fontWeight: bold,
              color: PdfColors.white,
              textAlign: pw.TextAlign.right),
          isHeader: true,
          alignment: pw.Alignment.centerRight),
    ]));

    for (int i = 0; i < pageItems.length; i++) {
      final item = pageItems[i];
      final absoluteIndex = _items.indexOf(item) + 1;
      final bg = i.isEven ? PdfColors.grey100 : PdfColors.white;
      itemTableRows.add(pw.TableRow(children: [
        tableCell(
            pw.RichText(
                text: pw.TextSpan(children: [
              pw.TextSpan(text: '$absoluteIndex. ', style: ts8),
              ..._buildPdfFormattedSpans(item.descCtrl.text, fontSize: 8.5),
            ])),
            bg: bg),
        tableCell(_buildPdfFormattedText(item.unitCtrl.text, fontSize: 8.5),
            bg: bg),
        tableCell(
            pw.Text(item.qtyCtrl.text,
                style: const pw.TextStyle(fontSize: 8.5),
                textAlign: pw.TextAlign.right),
            bg: bg,
            alignment: pw.Alignment.centerRight),
        tableCell(
            pw.Text('PKR ${item.rate.toStringAsFixed(0)}',
                style: const pw.TextStyle(fontSize: 8.5),
                textAlign: pw.TextAlign.right),
            bg: bg,
            alignment: pw.Alignment.centerRight),
        tableCell(
            pw.Text('PKR ${item.amount.toStringAsFixed(0)}',
                style: pw.TextStyle(fontSize: 9, fontWeight: bold),
                textAlign: pw.TextAlign.right),
            bg: bg,
            alignment: pw.Alignment.centerRight),
      ]));
    }

    w.add(pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FixedColumnWidth(30),
        2: const pw.FixedColumnWidth(30),
        3: const pw.FixedColumnWidth(45),
        4: const pw.FixedColumnWidth(55),
      },
      children: itemTableRows,
    ));

    if (isLastPage) {
      // Totals
      w.add(pw.SizedBox(height: 2));
      w.add(pw.Divider(thickness: 0.5, color: PdfColors.grey400));
      w.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text('Subtotal : ', style: ts9),
        pw.Text('PKR ${_subtotal.toStringAsFixed(0)}',
            style: pw.TextStyle(fontSize: 11, fontWeight: bold)),
      ]));
      if (_applyTax) {
        w.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Text('GST ${_taxPct.toStringAsFixed(0)}% : ', style: ts9),
          pw.Text('PKR ${_taxAmount.toStringAsFixed(0)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: bold)),
        ]));
      }
      w.add(pw.Container(
        color: navyColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('GRAND TOTAL',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: bold, color: PdfColors.white)),
              pw.Text('PKR ${_grandTotal.toStringAsFixed(0)}',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: bold, color: amberColor)),
            ]),
      ));

      // Grand total in words/millions
      if (_grandTotal >= 1000000) {
        w.add(pw.SizedBox(height: 1));
        w.add(pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
              '( ${(_grandTotal / 1000000).toStringAsFixed(3)} Million PKR )',
              style: pw.TextStyle(fontSize: 10, color: navyColor)),
        ));
      }

      w.add(pw.SizedBox(height: 3));

      // Terms
      if (_termsCtrl.text.isNotEmpty) {
        w.add(_buildPdfFormattedText('Terms & Conditions:',
            fontSize: 10, fontWeight: bold, color: navyColor));
        for (final line in _termsCtrl.text.split('\n')) {
          if (line.trim().isNotEmpty) {
            w.add(pw.RichText(
                text: pw.TextSpan(children: [
              const pw.TextSpan(
                  text: '  • ',
                  style: pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
              ..._buildPdfFormattedSpans(line,
                  fontSize: 9.5, color: PdfColors.grey700),
            ])));
          }
        }
        w.add(pw.SizedBox(height: 3));
      }

      w.add(pw.Text(
        'Looking forward for your positive response and we hope that this is the start of a faithful working relationship between us.',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ));
      w.add(pw.SizedBox(height: 1));
      w.add(pw.Text(
        'In case of confirmation of order 80% will be advance.',
        style: pw.TextStyle(
            fontSize: 10, fontWeight: bold, color: PdfColors.grey800),
      ));
      w.add(pw.SizedBox(height: 2));

      w.add(pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Thank You,',
                style: const pw.TextStyle(
                    fontSize: 9.5, color: PdfColors.grey800)),
            pw.Text('Ajmal Khan Jadoon,',
                style: pw.TextStyle(
                    fontSize: 9.5, fontWeight: bold, color: PdfColors.grey900)),
            pw.Text('CEO',
                style: const pw.TextStyle(
                    fontSize: 9.5, color: PdfColors.grey800)),
            pw.Text('Friend & Friends International',
                style: const pw.TextStyle(
                    fontSize: 9.5, color: PdfColors.grey800)),
          ],
        ),
      ));

      w.add(pw.SizedBox(height: 2));
      w.add(_buildPdfBottomContact());
    }

    return w;
  }

  pw.Widget _buildPdfBottomContact() {
    const foot = pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
            'Head Office : House CB-301, 1st Floor, Street 2, Afshan Colony, Rawalpindi Cantt',
            style: foot),
        pw.Text(
            'Branch Office: House 310, Lower Khalilzai, Garhi Pana Chowk, Nawan Shehr Abbottabad.',
            style: foot),
        pw.Text('Contact : Cell: 0311-5177747', style: foot),
        pw.Text('Email : fnfpvtltd@gmail.com', style: foot),
      ],
    );
  }

  // ── Text Summary ─────────────────────────────────────────────────────────

  String _generateSummary() {
    final now = DateTime.now();
    final buf = StringBuffer();
    buf.writeln('════════════════════════════════════════════════');
    buf.writeln('         FRIEND & FRIENDS INTERNATIONAL');
    buf.writeln('              SUPPLY QUOTATION');
    buf.writeln('════════════════════════════════════════════════');
    buf.writeln('Date : ${now.day}/${now.month}/${now.year}');
    if (_refCtrl.text.isNotEmpty) {
      buf.writeln('$_labelRef     : ${_refCtrl.text}');
    }
    if (_toCtrl.text.isNotEmpty) {
      buf.writeln('$_labelTo      : ${_toCtrl.text}');
    }
    if (_subjectCtrl.text.isNotEmpty) {
      buf.writeln('$_labelSubject : ${_subjectCtrl.text}');
    }
    if (_locationCtrl.text.isNotEmpty) {
      buf.writeln('$_labelLocation: ${_locationCtrl.text}');
    }
    buf.writeln('');
    buf.writeln('──── ITEMS ──────────────────────────────────────');
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      buf.writeln('${i + 1}. ${item.descCtrl.text}');
      buf.writeln(
          '   ${item.qtyCtrl.text} ${item.unitCtrl.text} × PKR ${item.rate.toStringAsFixed(0)} = PKR ${item.amount.toStringAsFixed(0)}');
    }
    buf.writeln('');
    buf.writeln('Subtotal : PKR ${_subtotal.toStringAsFixed(0)}');
    if (_applyTax) {
      buf.writeln(
          'GST ${_taxPct.toStringAsFixed(0)}%: PKR ${_taxAmount.toStringAsFixed(0)}');
    }
    buf.writeln('GRAND TOTAL: PKR ${_grandTotal.toStringAsFixed(0)}');
    if (_grandTotal >= 1000000) {
      buf.writeln(
          '             ( ${(_grandTotal / 1000000).toStringAsFixed(3)} Million PKR )');
    }
    buf.writeln('════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('Looking forward for your positive response and');
    buf.writeln('we hope that this is the start of a faithful');
    buf.writeln('working relationship between us.');
    buf.writeln('');
    buf.writeln('In case of confirmation of order 80% will be advance.');
    buf.writeln('');
    buf.writeln('                                      Thank You,');
    buf.writeln('                             Ajmal Khan Jadoon,');
    buf.writeln('                                           CEO');
    buf.writeln('                    Friend & Friends International');
    buf.writeln('');
    buf.writeln('════════════════════════════════════════════════');
    buf.writeln('Head Office  : House CB-301, 1st Floor, Street 2,');
    buf.writeln('               Afshan Colony, Rawalpindi Cantt');
    buf.writeln('Branch Office: House 310, Lower Khalilzai,');
    buf.writeln('               Garhi Pana Chowk, Nawan Shehr Abbottabad.');
    buf.writeln('Contact      : Cell: 0311-5177747');
    buf.writeln('Email        : fnfpvtltd@gmail.com');
    buf.writeln('════════════════════════════════════════════════');
    return buf.toString();
  }

  // ── Rename label ─────────────────────────────────────────────────────────

  void _renameLabel(String current, ValueChanged<String> onSaved) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Field Label',
            style: TextStyle(
                color: Color(0xFF1A3A5C),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. To, Supply of, PO No…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF1A3A5C), width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A5C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) onSaved(val);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _refCtrl.dispose();
    _locationCtrl.dispose();
    _termsCtrl.dispose();
    _taxPctCtrl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Supply Quotation'),
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasSaved)
            IconButton(
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: 'Load Last Order',
                onPressed: _loadLast),
          IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save Order',
              onPressed: _save),
          IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Generate PDF',
              onPressed: _generatePdf),
          IconButton(
              icon: const Icon(Icons.visibility_outlined),
              tooltip: 'Preview PDF',
              onPressed: _previewPdf),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'share') {
                _showSnack('Copy the text from the dialog below');
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Text Summary'),
                    content: SelectableText(_generateSummary(),
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'))
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'share',
                  child: Row(children: [
                    Icon(Icons.text_snippet_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Text Summary'),
                  ])),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header card ───────────────────────────────────────────────
          _sectionCard('Order Details', [
            Row(children: [
              const Icon(Icons.info_outline, size: 12, color: Colors.grey),
              const SizedBox(width: 6),
              Flexible(
                  child: Text('Tap ✏ next to a label to rename it',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500))),
            ]),
            const SizedBox(height: 12),
            _editField(_toCtrl, _labelTo, 'e.g. Pak Army / Mr. Zaid',
                Icons.person_outline,
                onRename: () => _renameLabel(
                    _labelTo, (v) => setState(() => _labelTo = v))),
            const SizedBox(height: 10),
            _editField(_subjectCtrl, _labelSubject,
                'e.g. Construction Materials', Icons.inventory_2_outlined,
                onRename: () => _renameLabel(
                    _labelSubject, (v) => setState(() => _labelSubject = v))),
            const SizedBox(height: 10),
            _editField(
                _refCtrl, _labelRef, 'e.g. RFQ-2024-001', Icons.tag_outlined,
                onRename: () => _renameLabel(
                    _labelRef, (v) => setState(() => _labelRef = v))),
            const SizedBox(height: 10),
            _editField(_locationCtrl, _labelLocation,
                'e.g. Rawalpindi, Abbottabad', Icons.location_on_outlined,
                onRename: () => _renameLabel(
                    _labelLocation, (v) => setState(() => _labelLocation = v))),
          ]),
          const SizedBox(height: 14),

          // ── Items ─────────────────────────────────────────────────────
          _sectionCard('Supply Items', [
            // Header row
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(
                    flex: 4,
                    child: Text('Description',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A3A5C)))),
                SizedBox(
                    width: 52,
                    child: Text('Unit',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A3A5C)))),
                SizedBox(
                    width: 52,
                    child: Text('Qty',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A3A5C)),
                        textAlign: TextAlign.right)),
                SizedBox(
                    width: 72,
                    child: Text('Rate (PKR)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A3A5C)),
                        textAlign: TextAlign.right)),
                SizedBox(width: 30),
              ]),
            ),
            const Divider(height: 1),
            const SizedBox(height: 6),

            for (int i = 0; i < _items.length; i++) _buildItemRow(i),

            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A3A5C),
                  side: const BorderSide(color: Color(0xFF1A3A5C)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // ── Totals card ───────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
              ],
            ),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _totalRow('Subtotal', _subtotal),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                const Text('Apply GST / Tax',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1A3A5C))),
                const SizedBox(width: 8),
                Switch(
                  value: _applyTax,
                  activeThumbColor: const Color(0xFF1A3A5C),
                  onChanged: (v) => setState(() => _applyTax = v),
                ),
                if (_applyTax) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 55,
                    child: TextField(
                      controller: _taxPctCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                      decoration: InputDecoration(
                        suffixText: '%',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF1A3A5C), width: 2)),
                      ),
                    ),
                  ),
                ],
              ]),
              if (_applyTax)
                _totalRow('GST ${_taxPct.toStringAsFixed(0)}%', _taxAmount),
              const Divider(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1A3A5C), Color(0xFF0D2D4F)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('GRAND TOTAL',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('PKR ${_grandTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Color(0xFFF5A623),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            if (_grandTotal >= 1000000)
                              Text(
                                  '${(_grandTotal / 1000000).toStringAsFixed(3)} M PKR',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11)),
                          ]),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Terms ─────────────────────────────────────────────────────
          _sectionCard('Terms & Notes', [
            TextField(
              controller: _termsCtrl,
              maxLines: 5,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter terms, payment conditions, delivery notes…',
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF1A3A5C), width: 2)),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // ── Actions ───────────────────────────────────────────────────
          Row(children: [
            Expanded(
                child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A5C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton.icon(
              onPressed: _generatePdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Generate PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5A623),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _previewPdf,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Preview PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A3A5C),
                side: const BorderSide(color: Color(0xFF1A3A5C)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildItemRow(int i) {
    final item = _items[i];
    return StatefulBuilder(builder: (ctx, setSub) {
      // listen to changes for live amount display
      void onChange() => setState(() {});
      item.qtyCtrl.removeListener(onChange);
      item.rateCtrl.removeListener(onChange);
      item.qtyCtrl.addListener(onChange);
      item.rateCtrl.addListener(onChange);

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: i.isEven ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Description row
          Row(children: [
            Text('${i + 1}.',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A3A5C))),
            const SizedBox(width: 6),
            Expanded(
                child: TextField(
              controller: item.descCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Item description…',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF1A3A5C), width: 1.5)),
              ),
            )),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => _removeItem(i),
              icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade300),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ]),
          const SizedBox(height: 8),
          // Unit / Qty / Rate row
          Row(children: [
            // Unit dropdown
            Expanded(child: _miniField(item.unitCtrl, 'Unit', isUnit: true)),
            const SizedBox(width: 6),
            Expanded(child: _miniField(item.qtyCtrl, 'Qty', isNum: true)),
            const SizedBox(width: 6),
            Expanded(
                flex: 2,
                child: _miniField(item.rateCtrl, 'Rate (PKR)', isNum: true)),
          ]),
          const SizedBox(height: 6),
          // Amount
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A5C).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Amount: PKR ${item.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A3A5C))),
            ),
          ),
        ]),
      );
    });
  }

  Widget _miniField(TextEditingController ctrl, String hint,
      {bool isNum = false, bool isUnit = false}) {
    final units = [
      'Pcs',
      'Kg',
      'Ton',
      'Meter',
      'Sqft',
      'Liter',
      'Box',
      'Bag',
      'Set',
      'Pair',
      'Bundle',
      'Each'
    ];
    if (isUnit) {
      return DropdownButtonFormField<String>(
        initialValue: units.contains(ctrl.text) ? ctrl.text : null,
        hint: Text(ctrl.text.isNotEmpty ? ctrl.text : 'Unit',
            style: const TextStyle(fontSize: 12)),
        items: units
            .map((u) => DropdownMenuItem(
                value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
            .toList(),
        onChanged: (v) => setState(() => ctrl.text = v ?? ctrl.text),
        isDense: true,
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: const TextStyle(fontSize: 11),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF1A3A5C), width: 1.5)),
        ),
      );
    }
    return TextField(
      controller: ctrl,
      keyboardType: isNum
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters:
          isNum ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : [],
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 1.5)),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A5C).withValues(alpha: 0.04),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                    color: const Color(0xFFF5A623),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A3A5C))),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children)),
      ]),
    );
  }

  Widget _editField(
      TextEditingController ctrl, String label, String hint, IconData icon,
      {required VoidCallback onRename}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon,
            size: 14, color: const Color(0xFF1A3A5C).withValues(alpha: 0.6)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A3A5C))),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRename,
          child: Tooltip(
              message: 'Rename label',
              child: Icon(Icons.edit_outlined,
                  size: 13,
                  color: const Color(0xFFF5A623).withValues(alpha: 0.8))),
        ),
      ]),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 2)),
        ),
      ),
    ]);
  }

  Widget _totalRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('$label : ',
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        Text('PKR ${amount.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3A5C))),
      ]),
    );
  }
}
