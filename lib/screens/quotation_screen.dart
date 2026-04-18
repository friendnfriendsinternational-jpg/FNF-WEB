import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';

import 'pdf_preview_screen.dart';

// ─── Data Model ─────────────────────────────────────────────────────────────

class MaterialItem {
  String id;
  String name;
  String unit;
  bool isCustom;
  bool enabled;
  late TextEditingController rateCtrl;
  late TextEditingController qtyCtrl;
  late TextEditingController nameCtrl;

  MaterialItem({
    required this.id,
    required this.name,
    required this.unit,
    required double qtyPerSqFt,
    required double rate,
    this.isCustom = false,
    this.enabled = true,
  }) {
    rateCtrl = TextEditingController(text: rate.toStringAsFixed(0));
    qtyCtrl = TextEditingController(text: qtyPerSqFt.toStringAsFixed(3));
    nameCtrl = TextEditingController(text: name);
  }

  double get rate => double.tryParse(rateCtrl.text) ?? 0;
  double get qtyPerSqFt => double.tryParse(qtyCtrl.text) ?? 0;
  double costForArea(double area) => enabled ? qtyPerSqFt * area * rate : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': nameCtrl.text,
        'unit': unit,
        'qty': qtyCtrl.text,
        'rate': rateCtrl.text,
        'isCustom': isCustom,
        'enabled': enabled,
      };

  void dispose() {
    rateCtrl.dispose();
    qtyCtrl.dispose();
    nameCtrl.dispose();
  }
}

// ─── Custom Add-on Model ────────────────────────────────────────────────────

class CustomAddon {
  late TextEditingController nameCtrl;
  late TextEditingController costCtrl;

  CustomAddon({String name = '', String cost = '0'}) {
    nameCtrl = TextEditingController(text: name);
    costCtrl = TextEditingController(text: cost);
  }

  double get costPKR => (double.tryParse(costCtrl.text) ?? 0) * 1000000;
  String get label =>
      nameCtrl.text.isNotEmpty ? nameCtrl.text : 'Custom Add-on';

  Map<String, dynamic> toJson() =>
      {'name': nameCtrl.text, 'cost': costCtrl.text};

  void dispose() {
    nameCtrl.dispose();
    costCtrl.dispose();
  }
}

class CustomQuotationRow {
  late TextEditingController labelCtrl;
  late TextEditingController detailCtrl;
  late List<TextEditingController> cells;

  CustomQuotationRow({
    String label = '',
    String detail = '',
    List<String>? cellValues,
    int columnCount = 5,
  }) {
    labelCtrl = TextEditingController(text: label);
    detailCtrl = TextEditingController(text: detail);
    final values = cellValues ?? List.generate(columnCount, (_) => '');
    cells = values.map((v) => TextEditingController(text: v)).toList();
    while (cells.length < columnCount) {
      cells.add(TextEditingController());
    }
  }

  Map<String, dynamic> toJson() => {
        'label': labelCtrl.text,
        'detail': detailCtrl.text,
        'cells': cells.map((c) => c.text).toList(),
      };

  void ensureColumns(int columnCount) {
    while (cells.length < columnCount) {
      cells.add(TextEditingController());
    }
    while (cells.length > columnCount) {
      final removed = cells.removeLast();
      removed.dispose();
    }
  }

  void dispose() {
    labelCtrl.dispose();
    detailCtrl.dispose();
    for (final c in cells) {
      c.dispose();
    }
  }
}

List<MaterialItem> _defaultMaterials() => [
      MaterialItem(
          id: 'cement',
          name: 'Cement',
          unit: 'Bags',
          qtyPerSqFt: 0.45,
          rate: 1400),
      MaterialItem(
          id: 'sand', name: 'Sand', unit: 'Cft', qtyPerSqFt: 0.90, rate: 28),
      MaterialItem(
          id: 'crush',
          name: 'Crush / Gravel',
          unit: 'Cft',
          qtyPerSqFt: 0.50,
          rate: 40),
      MaterialItem(
          id: 'steel',
          name: 'Steel / Sarya',
          unit: 'Kg',
          qtyPerSqFt: 3.50,
          rate: 340),
      MaterialItem(
          id: 'bricks',
          name: 'Bricks',
          unit: 'Pieces',
          qtyPerSqFt: 9.00,
          rate: 18),
      MaterialItem(
          id: 'tiles',
          name: 'Tiles / Flooring',
          unit: 'Sqft',
          qtyPerSqFt: 1.05,
          rate: 120),
      MaterialItem(
          id: 'paint',
          name: 'Paint',
          unit: 'Litres',
          qtyPerSqFt: 0.12,
          rate: 380),
      MaterialItem(
          id: 'plumbing',
          name: 'Plumbing Works',
          unit: 'Sqft',
          qtyPerSqFt: 1.00,
          rate: 280),
      MaterialItem(
          id: 'electric',
          name: 'Electrical Works',
          unit: 'Sqft',
          qtyPerSqFt: 1.00,
          rate: 220),
      MaterialItem(
          id: 'labor',
          name: 'Labor / Mistri',
          unit: 'Sqft',
          qtyPerSqFt: 1.00,
          rate: 1200),
    ];

// ─── Screen ─────────────────────────────────────────────────────────────────

class QuotationScreen extends StatefulWidget {
  /// Pre-populated data from the gallery. When set the screen opens in "edit" mode.
  final Map<String, dynamic>? initialData;
  final bool startInCustomMode;
  const QuotationScreen(
      {super.key, this.initialData, this.startInCustomMode = false});

  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Gallery tracking — null means this is a new quotation
  String? _galleryId;

  // Project Details
  final _clientCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _projectCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  int _floors = 1;
  int _rooms = 3;
  int _bathrooms = 2;
  String _projectType = 'Standard';
  String _foundation = 'Normal Strip';

  // Custom Foundation
  final _foundationDescCtrl = TextEditingController();
  final _foundationCostCtrl = TextEditingController(text: '0');

  // Standard Extras
  bool _hasBasement = false;
  bool _hasBoundaryWall = false;
  bool _hasCarPorch = false;
  bool _hasPool = false;
  bool _hasServantQuarter = false;

  // Custom Add-ons (multiple)
  List<CustomAddon> _customAddons = [];

  // Editable field labels — user can rename these freely
  String _labelClient = 'Client Name';
  String _labelSubject = 'Subject';
  String _labelProject = 'Project';
  String _labelLocation = 'Location';

  // Materials
  List<MaterialItem> _materials = [];

  // Results
  bool _calculated = false;
  bool _useTable = true;
  bool _customQuotationMode = false;
  bool _customAutoCalculator = true;
  String _customRowHeader = 'Row';
  double _basePerSqFt = 0;
  double _baseCost = 0;
  double _extrasCost = 0;
  double _totalCost = 0;
  double _effectiveArea = 0;
  List<Map<String, dynamic>> _breakdown = [];
  List<TextEditingController> _customHeaders = [];
  List<CustomQuotationRow> _customRows = [];
  final _customTotalOverrideCtrl = TextEditingController();

  // Saved-quotation flag (for the single last-quotation banner)
  bool _hasSavedQuotation = false;

  // Footer toggle
  final bool _includeFooter = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: 3, vsync: this, initialIndex: widget.startInCustomMode ? 2 : 0);
    _initCustomQuotationDefaults();
    _customQuotationMode = widget.startInCustomMode;

    if (widget.initialData != null) {
      // Opened from gallery — load data immediately, skip material loading from prefs
      _applyData(widget.initialData!);
      _loadMaterials();
    } else {
      _loadMaterials().then((_) => _checkSavedQuotation());
    }

    // Real-time recalc listeners
    _areaCtrl.addListener(_autoCalc);
    _foundationCostCtrl.addListener(_autoCalc);
  }

  /// Apply a project data map to all form fields (used by gallery load & last-quotation load).
  void _applyData(Map<String, dynamic> d) {
    _galleryId = d['id'] as String?;
    _clientCtrl.text = d['client'] ?? '';
    _subjectCtrl.text = d['subject'] ?? '';
    _descriptionCtrl.text = d['description'] ?? '';
    _projectCtrl.text = d['project'] ?? '';
    _locationCtrl.text = d['location'] ?? '';
    _areaCtrl.text = d['area'] ?? '';
    _floors = d['floors'] ?? 1;
    _rooms = d['rooms'] ?? 3;
    _bathrooms = d['bathrooms'] ?? 2;
    _projectType = d['projectType'] ?? 'Standard';
    _foundation = d['foundation'] ?? 'Normal Strip';
    _foundationDescCtrl.text = d['foundationDesc'] ?? '';
    _foundationCostCtrl.text = d['foundationCost'] ?? '0';
    _hasBasement = d['hasBasement'] ?? false;
    _hasBoundaryWall = d['hasBoundaryWall'] ?? false;
    _hasCarPorch = d['hasCarPorch'] ?? false;
    _hasPool = d['hasPool'] ?? false;
    _hasServantQuarter = d['hasServantQuarter'] ?? false;
    // Load multiple custom add-ons
    for (final a in _customAddons) {
      a.dispose();
    }
    _customAddons = [];
    final addonsRaw = d['customAddons'];
    if (addonsRaw is List && addonsRaw.isNotEmpty) {
      for (final a in addonsRaw) {
        _customAddons
            .add(CustomAddon(name: a['name'] ?? '', cost: a['cost'] ?? '0'));
      }
    } else if (d['hasCustomAddon'] == true) {
      // Backward compat: single add-on saved in old format
      _customAddons.add(CustomAddon(
          name: d['customAddonName'] ?? '', cost: d['customAddonCost'] ?? '0'));
    }
    _labelClient = d['labelClient'] ?? 'Client Name';
    _labelSubject = d['labelSubject'] ?? 'Subject';
    _labelProject = d['labelProject'] ?? 'Project';
    _labelLocation = d['labelLocation'] ?? 'Location';

    _customQuotationMode = d['customQuotationMode'] ?? false;
    _customAutoCalculator = d['customAutoCalculator'] ?? true;
    _customRowHeader = d['customRowHeader'] ?? 'Row';
    _customTotalOverrideCtrl.text = d['customTotalOverride'] ?? '';
    for (final h in _customHeaders) {
      h.dispose();
    }
    _customHeaders = [];
    final headersRaw = d['customHeaders'];
    if (headersRaw is List && headersRaw.isNotEmpty) {
      _customHeaders = headersRaw
          .map((h) => TextEditingController(text: h.toString()))
          .toList();
    } else {
      _customHeaders = [
        TextEditingController(text: 'Description'),
        TextEditingController(text: 'Qty'),
        TextEditingController(text: 'Unit'),
        TextEditingController(text: 'Rate (PKR)'),
        TextEditingController(text: 'Amount'),
      ];
    }

    for (final r in _customRows) {
      r.dispose();
    }
    _customRows = [];
    final rowsRaw = d['customRows'];
    if (rowsRaw is List && rowsRaw.isNotEmpty) {
      for (final r in rowsRaw) {
        final cellsRaw = (r['cells'] as List?)?.map((e) => '$e').toList();
        final row = CustomQuotationRow(
          label: r['label'] ?? '',
          detail: r['detail'] ?? '',
          cellValues: cellsRaw,
          columnCount: _customHeaders.length,
        );
        _customRows.add(row);
      }
    }
    if (_customRows.isEmpty) {
      _customRows.add(CustomQuotationRow(columnCount: _customHeaders.length));
    }
  }

  void _initCustomQuotationDefaults() {
    _customHeaders = [
      TextEditingController(text: 'Description'),
      TextEditingController(text: 'Qty'),
      TextEditingController(text: 'Unit'),
      TextEditingController(text: 'Rate (PKR)'),
      TextEditingController(text: 'Amount'),
    ];
    _customRows = [CustomQuotationRow(columnCount: _customHeaders.length)];
  }

  // ── Formatting ───────────────────────────────────────────────────────────

  /// Always display in decimal Millions PKR — no Lakh, no Crore.
  String _formatPKR(double amount) {
    final millions = amount / 1000000;
    final text = millions
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$text Million PKR';
  }

  List<pw.InlineSpan> _buildPdfFormattedSpans(String input,
      {double fontSize = 9,
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

    // WhatsApp-like markers: *bold*, _italic_, ~strike~, __underline__
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
      {double fontSize = 9,
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

  // ── Persistence: Materials ───────────────────────────────────────────────

  Future<void> _loadMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('materials_v2');
    if (saved != null) {
      try {
        final list = jsonDecode(saved) as List;
        final loaded = <MaterialItem>[];
        final defaults = _defaultMaterials();
        for (final d in defaults) {
          final match =
              list.firstWhere((e) => e['id'] == d.id, orElse: () => null);
          if (match != null) {
            d.rateCtrl.text = match['rate'] ?? d.rateCtrl.text;
            d.qtyCtrl.text = match['qty'] ?? d.qtyCtrl.text;
            d.enabled = match['enabled'] ?? true;
          }
          loaded.add(d);
        }
        for (final e in list) {
          if (e['isCustom'] == true) {
            loaded.add(MaterialItem(
              id: e['id'],
              name: e['name'],
              unit: e['unit'],
              qtyPerSqFt: double.tryParse(e['qty'] ?? '0') ?? 0,
              rate: double.tryParse(e['rate'] ?? '0') ?? 0,
              isCustom: true,
              enabled: e['enabled'] ?? true,
            ));
          }
        }
        setState(() => _materials = loaded);
        return;
      } catch (_) {}
    }
    setState(() => _materials = _defaultMaterials());
  }

  Future<void> _saveMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'materials_v2', jsonEncode(_materials.map((m) => m.toJson()).toList()));
  }

  // ── Persistence: Full Quotation + Gallery ────────────────────────────────

  Future<void> _checkSavedQuotation() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('project_gallery_v1');
    if (raw != null && mounted) {
      try {
        final list = jsonDecode(raw) as List;
        if (list.isNotEmpty) setState(() => _hasSavedQuotation = true);
      } catch (_) {}
    }
  }

  /// Build the data map for the current quotation state.
  Map<String, dynamic> _buildDataMap() => {
        'id': _galleryId ?? 'proj_${DateTime.now().millisecondsSinceEpoch}',
        'client': _clientCtrl.text,
        'subject': _subjectCtrl.text,
        'description': _descriptionCtrl.text,
        'project': _projectCtrl.text,
        'location': _locationCtrl.text,
        'area': _areaCtrl.text,
        'floors': _floors,
        'rooms': _rooms,
        'bathrooms': _bathrooms,
        'projectType': _projectType,
        'foundation': _foundation,
        'foundationDesc': _foundationDescCtrl.text,
        'foundationCost': _foundationCostCtrl.text,
        'hasBasement': _hasBasement,
        'hasBoundaryWall': _hasBoundaryWall,
        'hasCarPorch': _hasCarPorch,
        'hasPool': _hasPool,
        'hasServantQuarter': _hasServantQuarter,
        'customAddons': _customAddons.map((a) => a.toJson()).toList(),
        'labelClient': _labelClient,
        'labelSubject': _labelSubject,
        'labelProject': _labelProject,
        'labelLocation': _labelLocation,
        'customQuotationMode': _customQuotationMode,
        'customAutoCalculator': _customAutoCalculator,
        'customRowHeader': _customRowHeader,
        'customTotalOverride': _customTotalOverrideCtrl.text,
        'customHeaders': _customHeaders.map((h) => h.text).toList(),
        'customRows': _customRows.map((r) => r.toJson()).toList(),
        'totalCostM': _totalCost / 1000000,
        'savedAt': DateTime.now().toIso8601String(),
      };

  /// Save or update this quotation in the gallery list.
  Future<void> _saveQuotation() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _buildDataMap();

    // Assign ID if new
    _galleryId ??= data['id'] as String;
    data['id'] = _galleryId!;

    // Load existing gallery
    List<dynamic> gallery = [];
    final raw = prefs.getString('project_gallery_v1');
    if (raw != null) {
      try {
        gallery = jsonDecode(raw) as List;
      } catch (_) {}
    }

    // Update existing entry or prepend new one
    final idx = gallery.indexWhere((p) => p['id'] == _galleryId);
    if (idx >= 0) {
      gallery[idx] = data;
    } else {
      gallery.insert(0, data);
    }

    await prefs.setString('project_gallery_v1', jsonEncode(gallery));
    // Also keep last-quotation key for backward compat
    await prefs.setString('last_quotation_v3', jsonEncode(data));

    if (mounted) {
      setState(() => _hasSavedQuotation = true);
      _showSnack('Project saved to gallery');
    }
  }

  Future<void> _loadQuotation() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('project_gallery_v1');
    if (raw == null) {
      _showSnack('No saved projects found');
      return;
    }
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        _showSnack('No saved projects found');
        return;
      }
      // Load the most recent one (already sorted newest first when saved)
      list.sort((a, b) {
        final aDate = DateTime.tryParse(a['savedAt'] ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['savedAt'] ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      final d = list.first;
      setState(() => _applyData(d));
      final savedAt =
          d['savedAt'] != null ? DateTime.tryParse(d['savedAt']) : null;
      final label = savedAt != null
          ? '${savedAt.day}/${savedAt.month}/${savedAt.year}'
          : 'previously';
      _showSnack(
          'Last project from $label loaded — tap Calculate to update results');
      _tabCtrl.animateTo(0);
    } catch (_) {
      _showSnack('Failed to load saved project');
    }
  }

  // ── Calculation ──────────────────────────────────────────────────────────

  /// Silent recalculation — runs when fields change. No tab switch, no snack.
  void _autoCalc() {
    final area = double.tryParse(_areaCtrl.text.trim());
    if (area == null || area <= 0 || !_calculated) return;
    _runCalc(area, navigate: false);
  }

  void _calculate() {
    final areaText = _areaCtrl.text.trim();
    if (areaText.isEmpty) {
      _showSnack('Please enter the area in square feet');
      return;
    }
    final area = double.tryParse(areaText);
    if (area == null || area <= 0) {
      _showSnack('Please enter a valid area');
      return;
    }
    _saveMaterials();
    _runCalc(area, navigate: true);
  }

  void _runCalc(double area, {required bool navigate}) {
    final effectiveArea = area * (1 + 0.85 * (_floors - 1));

    // Material costs
    final breakdown = <Map<String, dynamic>>[];
    double baseCost = 0;
    for (final m in _materials) {
      if (!m.enabled) continue;
      final cost = m.costForArea(effectiveArea);
      baseCost += cost;
      breakdown.add({
        'name': m.nameCtrl.text,
        'qty': m.qtyPerSqFt * effectiveArea,
        'unit': m.unit,
        'rate': m.rate,
        'cost': cost,
      });
    }

    final double perSqFt = effectiveArea > 0 ? baseCost / effectiveArea : 0.0;

    // Extras cost (all in PKR internally)
    double extrasCost = 0;
    if (_hasBasement) extrasCost += area * perSqFt * 0.40;
    if (_hasBoundaryWall) extrasCost += 250000;
    if (_hasCarPorch) extrasCost += 200 * perSqFt * 0.50;
    if (_hasPool) extrasCost += 1200000;
    if (_hasServantQuarter) extrasCost += 150 * perSqFt * 0.65;

    // Custom foundation cost (entered in Millions)
    if (_foundation == 'Custom') {
      extrasCost += (double.tryParse(_foundationCostCtrl.text) ?? 0) * 1000000;
    }

    // Custom add-ons cost
    for (final a in _customAddons) {
      extrasCost += a.costPKR;
    }

    setState(() {
      _effectiveArea = effectiveArea;
      _basePerSqFt = perSqFt;
      _baseCost = baseCost;
      _extrasCost = extrasCost;
      _totalCost = baseCost + extrasCost;
      _breakdown = breakdown;
      _calculated = true;
    });

    if (navigate) _tabCtrl.animateTo(2);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _generateSummary() {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final buf = StringBuffer();
    buf.writeln('════════════════════════════════════════════════');
    buf.writeln('         FRIEND & FRIENDS INTERNATIONAL');
    buf.writeln('════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('Date : $dateStr');
    buf.writeln('');
    if (_clientCtrl.text.isNotEmpty) {
      buf.writeln('$_labelClient,');
      buf.writeln(_clientCtrl.text);
    }
    if (_locationCtrl.text.isNotEmpty) {
      buf.writeln(_locationCtrl.text);
    }
    if (_subjectCtrl.text.isNotEmpty) {
      buf.writeln('$_labelSubject: ${_subjectCtrl.text}');
    }
    if (_projectCtrl.text.isNotEmpty) {
      buf.writeln('$_labelProject: ${_projectCtrl.text}');
    }
    if (_descriptionCtrl.text.isNotEmpty) {
      buf.writeln(_descriptionCtrl.text);
    }

    if (_customQuotationMode) {
      final isSingleColumnMode = _customHeaders.length == 1;
      buf.writeln('');
      buf.writeln('────────── CUSTOM QUOTATION ───────────────────');
      for (final row in _customRows) {
        final label = row.labelCtrl.text.trim().isEmpty
            ? 'Item'
            : row.labelCtrl.text.trim();
        final detail = row.detailCtrl.text.trim();
        buf.writeln(label);
        if (detail.isNotEmpty) {
          buf.writeln('  $detail');
        }
        final startIndex = isSingleColumnMode ? 0 : 1;
        for (var i = startIndex; i < _customHeaders.length; i++) {
          final head = _customHeaders[i].text.trim().isEmpty
              ? 'Column ${i + 1}'
              : _customHeaders[i].text.trim();
          final value = i < row.cells.length ? row.cells[i].text : '';
          if (value.trim().isNotEmpty) {
            buf.writeln('  $head: $value');
          }
        }
        buf.writeln('');
      }
      buf.writeln('════════════════════════════════════════════════');
      buf.writeln(
          '  CUSTOM TOTAL :  ${_formatPKR(_effectiveCustomQuotationTotal())}');
      buf.writeln('════════════════════════════════════════════════');
      if (_includeFooter) {
        buf.writeln('');
        buf.writeln('Looking forward for your positive response and');
        buf.writeln('we hope that this is the start of a faithful');
        buf.writeln('working relationship between us.');
        buf.writeln('');
        buf.writeln('In case of confirmation of order 80% will be advance.');
      }
      return buf.toString();
    }

    buf.writeln('');
    buf.writeln('────────── PROJECT DETAILS ─────────────────────');
    buf.writeln('Area             : ${_areaCtrl.text} Sqft');
    buf.writeln('No. of Floors    : $_floors');
    buf.writeln('Effective Area   : ${_effectiveArea.toStringAsFixed(0)} Sqft');
    buf.writeln('Project Type     : $_projectType');
    final foundationLabel = _foundation == 'Custom'
        ? 'Custom${_foundationDescCtrl.text.isNotEmpty ? ': ${_foundationDescCtrl.text}' : ''}'
        : _foundation;
    buf.writeln('Foundation       : $foundationLabel');
    buf.writeln('Rooms / Bathrooms: $_rooms Rooms, $_bathrooms Bathrooms');
    final extras = <String>[];
    if (_hasBasement) extras.add('Basement');
    if (_hasBoundaryWall) extras.add('Boundary Wall');
    if (_hasCarPorch) extras.add('Car Porch');
    if (_hasPool) extras.add('Swimming Pool');
    if (_hasServantQuarter) extras.add('Servant Quarter');
    for (final a in _customAddons) {
      if (a.nameCtrl.text.isNotEmpty) extras.add(a.nameCtrl.text);
    }
    if (extras.isNotEmpty) {
      buf.writeln('Extras           : ${extras.join(', ')}');
    }
    buf.writeln('');
    buf.writeln('────────── MATERIAL COST BREAKDOWN ─────────────');
    for (final item in _breakdown) {
      final qty = (item['qty'] as double).toStringAsFixed(1);
      final rate = (item['rate'] as double).toStringAsFixed(0);
      final cost = _formatPKR(item['cost'] as double);
      buf.writeln('  ${item['name']}');
      buf.writeln('    $qty ${item['unit']}  ×  PKR $rate  =  $cost');
    }
    buf.writeln('');
    if (_extrasCost > 0) {
      buf.writeln('────────── ADDITIONAL WORKS ─────────────────────');
      final area = double.tryParse(_areaCtrl.text) ?? 0;
      if (_hasBasement) {
        buf.writeln(
            '  Basement            : ${_formatPKR(area * _basePerSqFt * 0.40)}');
      }
      if (_hasBoundaryWall) {
        buf.writeln('  Boundary Wall       : ${_formatPKR(250000)}');
      }
      if (_hasCarPorch) {
        buf.writeln(
            '  Car Porch           : ${_formatPKR(200 * _basePerSqFt * 0.50)}');
      }
      if (_hasPool) {
        buf.writeln('  Swimming Pool       : ${_formatPKR(1200000)}');
      }
      if (_hasServantQuarter) {
        buf.writeln(
            '  Servant Quarter     : ${_formatPKR(150 * _basePerSqFt * 0.65)}');
      }
      if (_foundation == 'Custom') {
        final fc = (double.tryParse(_foundationCostCtrl.text) ?? 0) * 1000000;
        buf.writeln('  Custom Foundation   : ${_formatPKR(fc)}');
      }
      for (final a in _customAddons) {
        buf.writeln('  ${a.label}: ${_formatPKR(a.costPKR)}');
      }
      buf.writeln('');
    }
    buf.writeln('════════════════════════════════════════════════');
    buf.writeln('  Base Cost    :  ${_formatPKR(_baseCost)}');
    if (_extrasCost > 0) {
      buf.writeln('  Extras Cost  :  ${_formatPKR(_extrasCost)}');
    }
    buf.writeln('  ─────────────────────────────────────────────');
    buf.writeln('  TOTAL COST   :  ${_formatPKR(_totalCost)}');
    buf.writeln('  Rate per Sqft:  PKR ${_basePerSqFt.toStringAsFixed(0)}');
    buf.writeln('════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('Note: This is an estimated cost based on current');
    buf.writeln('market rates. Final cost may vary based on site');
    buf.writeln('conditions, design changes, and specifications.');
    if (!_customQuotationMode) {
      buf.writeln('Company use note: This estimate is for internal');
      buf.writeln('company reference only.');
    }
    buf.writeln('');
    if (_includeFooter) {
      buf.writeln('────────────────────────────────────────────────');
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
    }
    return buf.toString();
  }

  // ── PDF Generation ───────────────────────────────────────────────────────

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final letterheadData = await _loadLetterheadData();
    final letterheadImage = pw.MemoryImage(letterheadData.buffer.asUint8List());
    final navyColor = PdfColor.fromHex('#1A3A5C');
    final amberColor = PdfColor.fromHex('#F5A623');
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(21, 111, 21, 22),
        buildBackground: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Image(letterheadImage, fit: pw.BoxFit.fill),
        ),
      ),
      footer: (ctx) => _includeFooter && ctx.pageNumber == ctx.pagesCount
          ? pw.Container(
              width: double.infinity,
              height: 26,
              alignment: pw.Alignment.bottomLeft,
              child: _buildPdfBottomContact(),
            )
          : pw.SizedBox(),
      build: (ctx) => _buildPdfContent(navyColor, amberColor, dateStr,
          includeFooter: _includeFooter),
    ));

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
      final client = _clientCtrl.text.isNotEmpty
          ? _clientCtrl.text.replaceAll(' ', '_')
          : 'Quotation';
      await Printing.sharePdf(bytes: bytes, filename: 'FnF_$client.pdf');
    } catch (e) {
      _showSnack('Error generating PDF: $e');
    }
  }

  Future<void> _previewPdf() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: _customQuotationMode
              ? 'Custom Quotation Preview'
              : 'Estimate Quotation Preview',
          buildPdf: (_) => _buildPdfBytes(),
        ),
      ),
    );
  }

  List<pw.Widget> _buildPdfContent(
      PdfColor navyColor, PdfColor amberColor, String dateStr,
      {bool includeFooter = true}) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Date : $dateStr',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
    ));
    widgets.add(pw.SizedBox(height: 5));
    if (_clientCtrl.text.isNotEmpty) {
      widgets.add(_buildPdfFormattedText('$_labelClient,',
          fontSize: 11, fontWeight: pw.FontWeight.bold));
      widgets.add(_buildPdfFormattedText(_clientCtrl.text, fontSize: 11));
    }
    if (_locationCtrl.text.isNotEmpty) {
      widgets.add(_buildPdfFormattedText(_locationCtrl.text, fontSize: 11));
    }
    if (_subjectCtrl.text.isNotEmpty) {
      widgets.add(pw.RichText(
        text: pw.TextSpan(
          children: [
            ..._buildPdfFormattedSpans('$_labelSubject: ',
                fontSize: 11, fontWeight: pw.FontWeight.bold),
            ..._buildPdfFormattedSpans(_subjectCtrl.text, fontSize: 11),
          ],
        ),
      ));
    }
    if (_projectCtrl.text.isNotEmpty) {
      widgets.add(pw.RichText(
        text: pw.TextSpan(
          children: [
            ..._buildPdfFormattedSpans('$_labelProject: ',
                fontSize: 11, fontWeight: pw.FontWeight.bold),
            ..._buildPdfFormattedSpans(_projectCtrl.text, fontSize: 11),
          ],
        ),
      ));
    }
    if (_descriptionCtrl.text.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: pw.BoxDecoration(
          color: const PdfColor(0.976, 0.984, 1, 1),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(
              color: const PdfColor(0.5, 0.5, 0.5, 0.10), width: 0.7),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 2,
              height: 22,
              margin: const pw.EdgeInsets.only(right: 8),
              decoration:
                  const pw.BoxDecoration(color: PdfColor(0.2, 0.2, 0.2, 1)),
            ),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                    children: _buildPdfFormattedSpans(_descriptionCtrl.text,
                        fontSize: 9, color: PdfColors.black)),
              ),
            ),
          ],
        ),
      ));
    }
    widgets.add(pw.SizedBox(height: 8));

    if (!_customQuotationMode) {
      widgets.add(pw.SizedBox(height: 2));
    }

    // Cost estimate section
    widgets.add(pw.Container(
      color: navyColor,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Text(
          _customQuotationMode ? 'COST ESTIMATE' : 'ESTIMATE QUOTATION',
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    ));
    widgets.add(pw.SizedBox(height: 5));
    if (_customQuotationMode) {
      widgets.add(_buildCustomPdfTable(navyColor));
    } else if (_useTable) {
      widgets.add(_buildPdfTable(navyColor));
    } else {
      widgets.add(_buildPdfList());
    }

    // Extras section
    if (!_customQuotationMode && _extrasCost > 0) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Container(
        color: navyColor,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: pw.Text('ADDITIONAL WORKS',
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white)),
      ));
      widgets.add(pw.SizedBox(height: 4));

      final area = double.tryParse(_areaCtrl.text) ?? 0;
      if (_useTable) {
        final extrasRows = <List<String>>[];
        if (_hasBasement) {
          extrasRows.add([
            'Basement',
            '-',
            '-',
            '-',
            _formatPKR(area * _basePerSqFt * 0.40)
          ]);
        }
        if (_hasBoundaryWall) {
          extrasRows.add(['Boundary Wall', '-', '-', '-', _formatPKR(250000)]);
        }
        if (_hasCarPorch) {
          extrasRows.add([
            'Car Porch',
            '200',
            'Sqft',
            '50% rate',
            _formatPKR(200 * _basePerSqFt * 0.50)
          ]);
        }
        if (_hasPool) {
          extrasRows.add(['Swimming Pool', '-', '-', '-', _formatPKR(1200000)]);
        }
        if (_hasServantQuarter) {
          extrasRows.add([
            'Servant Quarter',
            '150',
            'Sqft',
            '65% rate',
            _formatPKR(150 * _basePerSqFt * 0.65)
          ]);
        }
        if (_foundation == 'Custom') {
          final fc = (double.tryParse(_foundationCostCtrl.text) ?? 0) * 1000000;
          final desc = _foundationDescCtrl.text.isNotEmpty
              ? _foundationDescCtrl.text
              : 'Custom Foundation';
          extrasRows.add([desc, '-', '-', 'Fixed', _formatPKR(fc)]);
        }
        for (final a in _customAddons) {
          extrasRows.add([a.label, '-', '-', 'Fixed', _formatPKR(a.costPKR)]);
        }
        if (extrasRows.isNotEmpty) {
          widgets.add(_buildExtrasPdfTable(navyColor, extrasRows));
        }
      } else {
        if (_hasBasement) {
          widgets.add(pw.Text(
              '  • Basement: ${_formatPKR(area * _basePerSqFt * 0.40)}',
              style: const pw.TextStyle(fontSize: 10)));
        }
        if (_hasBoundaryWall) {
          widgets.add(pw.Text('  • Boundary Wall: ${_formatPKR(250000)}',
              style: const pw.TextStyle(fontSize: 10)));
        }
        if (_hasCarPorch) {
          widgets.add(pw.Text(
              '  • Car Porch: ${_formatPKR(200 * _basePerSqFt * 0.50)}',
              style: const pw.TextStyle(fontSize: 10)));
        }
        if (_hasPool) {
          widgets.add(pw.Text('  • Swimming Pool: ${_formatPKR(1200000)}',
              style: const pw.TextStyle(fontSize: 10)));
        }
        if (_hasServantQuarter) {
          widgets.add(pw.Text(
              '  • Servant Quarter: ${_formatPKR(150 * _basePerSqFt * 0.65)}',
              style: const pw.TextStyle(fontSize: 10)));
        }
        if (_foundation == 'Custom') {
          final fc = (double.tryParse(_foundationCostCtrl.text) ?? 0) * 1000000;
          final desc = _foundationDescCtrl.text.isNotEmpty
              ? _foundationDescCtrl.text
              : 'Custom Foundation';
          widgets.add(pw.Text('  • $desc: ${_formatPKR(fc)}',
              style: const pw.TextStyle(fontSize: 10)));
        }
        for (final a in _customAddons) {
          widgets.add(pw.Text('  • ${a.label}: ${_formatPKR(a.costPKR)}',
              style: const pw.TextStyle(fontSize: 10)));
        }
      }
    }

    widgets.add(pw.SizedBox(height: 10));
    if (_customQuotationMode) {
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(color: navyColor),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('CUSTOM QUOTATION TOTAL',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.Text(_formatPKR(_effectiveCustomQuotationTotal()),
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: amberColor)),
            ]),
      ));
    } else {
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(color: navyColor),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (_extrasCost > 0) ...[
                pw.Text('Base Cost  :  ${_formatPKR(_baseCost)}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColor(1, 1, 1, 0.7))),
                pw.Text('Extras     :  ${_formatPKR(_extrasCost)}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColor(1, 1, 1, 0.7))),
                pw.SizedBox(height: 3),
              ],
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL ESTIMATED COST',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                    pw.Text(_formatPKR(_totalCost),
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: amberColor)),
                  ]),
              pw.SizedBox(height: 2),
              pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      'PKR ${_basePerSqFt.toStringAsFixed(0)} per Sqft',
                      style: const pw.TextStyle(
                          fontSize: 9.5, color: PdfColor(1, 1, 1, 0.54)))),
            ]),
      ));
    }
    if (!_customQuotationMode) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
        'Company use note: This estimate is for internal company reference only.',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ));
    }
    if (includeFooter) {
      widgets.add(pw.SizedBox(height: 14));
      widgets.add(pw.Divider(thickness: 0.5, color: PdfColors.grey400));
      widgets.add(pw.SizedBox(height: 8));

      widgets.add(pw.Text(
        'Looking forward for your positive response and we hope that this is the start of a faithful working relationship between us.',
        style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey800),
      ));
      widgets.add(pw.SizedBox(height: 5));
      widgets.add(pw.Text(
        'In case of confirmation of order 80% will be advance.',
        style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900),
      ));
      widgets.add(pw.SizedBox(height: 14));

      widgets.add(pw.Align(
        alignment: pw.Alignment.centerRight,
        child:
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Thank You,',
              style:
                  const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey800)),
          pw.SizedBox(height: 2),
          pw.Text('Ajmal Khan Jadoon,',
              style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900)),
          pw.Text('CEO',
              style:
                  const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey800)),
          pw.Text('Friend & Friends International',
              style:
                  const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey800)),
        ]),
      ));
    }

    return widgets;
  }

  pw.Widget _buildPdfBottomContact() {
    const foot = pw.TextStyle(fontSize: 9.2, color: PdfColors.grey800);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
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

  pw.Widget _buildPdfTable(PdfColor navyColor) {
    final headers = [
      'S.No',
      'Description',
      'Qty',
      'Unit',
      'Rate (PKR)',
      'Amount'
    ];
    final rows = _breakdown.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return [
        '${index + 1}',
        item['name'].toString(),
        (item['qty'] as double).toStringAsFixed(1),
        item['unit'].toString(),
        (item['rate'] as double).toStringAsFixed(0),
        _formatPKR(item['cost'] as double),
      ];
    }).toList();

    const textAligns = [
      pw.TextAlign.center,
      pw.TextAlign.left,
      pw.TextAlign.left,
      pw.TextAlign.right,
      pw.TextAlign.left,
      pw.TextAlign.right,
    ];

    pw.Widget cell(String text,
        {required int col,
        bool isHeader = false,
        bool isLastRow = false,
        double fontSize = 9.5}) {
      return pw.Container(
        decoration: isHeader
            ? pw.BoxDecoration(color: navyColor)
            : (!isLastRow
                ? const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(
                            color: PdfColors.grey200, width: 0.5)))
                : null),
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: _buildPdfFormattedText(
          text,
          fontSize: fontSize,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
          textAlign: textAligns[col],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),
        1: const pw.FlexColumnWidth(3.2),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(1.8),
        5: const pw.FlexColumnWidth(2.4),
      },
      children: [
        pw.TableRow(
          children: headers
              .asMap()
              .entries
              .map((entry) => cell(entry.value, col: entry.key, isHeader: true))
              .toList(),
        ),
        ...rows.asMap().entries.map((rowEntry) {
          final isLast = rowEntry.key == rows.length - 1;
          final row = rowEntry.value;
          return pw.TableRow(
            children: row
                .asMap()
                .entries
                .map((entry) =>
                    cell(entry.value, col: entry.key, isLastRow: isLast))
                .toList(),
          );
        }),
      ],
    );
  }

  pw.Widget _buildExtrasPdfTable(PdfColor navyColor, List<List<String>> rows) {
    const headers = ['Item', 'Qty', 'Unit', 'Rate', 'Amount'];
    const textAligns = [
      pw.TextAlign.left,
      pw.TextAlign.right,
      pw.TextAlign.left,
      pw.TextAlign.right,
      pw.TextAlign.right,
    ];

    pw.Widget cell(String text,
        {required int col,
        bool isHeader = false,
        bool isLastRow = false,
        double fontSize = 9}) {
      return pw.Container(
        decoration: isHeader
            ? pw.BoxDecoration(color: navyColor)
            : (!isLastRow
                ? const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(
                            color: PdfColors.grey200, width: 0.4)))
                : null),
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: _buildPdfFormattedText(
          text,
          fontSize: fontSize,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
          textAlign: textAligns[col],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          children: headers
              .asMap()
              .entries
              .map((entry) => cell(entry.value, col: entry.key, isHeader: true))
              .toList(),
        ),
        ...rows.asMap().entries.map((rowEntry) {
          final isLast = rowEntry.key == rows.length - 1;
          final row = rowEntry.value;
          return pw.TableRow(
            children: row
                .asMap()
                .entries
                .map((entry) =>
                    cell(entry.value, col: entry.key, isLastRow: isLast))
                .toList(),
          );
        }),
      ],
    );
  }

  pw.Widget _buildPdfList() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: _breakdown
          .map((item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(children: [
                  pw.Expanded(
                      flex: 4,
                      child: _buildPdfFormattedText(item['name'].toString(),
                          fontSize: 10)),
                  pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        '${(item['qty'] as double).toStringAsFixed(1)} ${item['unit']} × PKR ${(item['rate'] as double).toStringAsFixed(0)}',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700),
                      )),
                  pw.Text(_formatPKR(item['cost'] as double),
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ]),
              ))
          .toList(),
    );
  }

  double _parseCustomCellAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  int _findCustomColumnIndex(List<String> keywords) {
    for (var i = 0; i < _customHeaders.length; i++) {
      final head = _customHeaders[i].text.toLowerCase().trim();
      for (final key in keywords) {
        if (head.contains(key)) return i;
      }
    }
    return -1;
  }

  int _resolveCustomQtyIndex() {
    final idx = _findCustomColumnIndex(['qty', 'quantity']);
    if (idx >= 0) return idx;
    return _customHeaders.length > 1 ? 1 : -1;
  }

  int _resolveCustomRateIndex() {
    final idx = _findCustomColumnIndex(['rate', 'price', 'unit rate']);
    if (idx >= 0) return idx;
    return _customHeaders.length > 3 ? 3 : -1;
  }

  int _resolveCustomAmountIndex() {
    final idx = _findCustomColumnIndex(['amount', 'total', 'line total']);
    if (idx >= 0) return idx;
    return _customHeaders.length > 4 ? 4 : _customHeaders.length - 1;
  }

  void _recalculateAllCustomRowAmounts() {
    if (!_customAutoCalculator ||
        _customRows.isEmpty ||
        _customHeaders.isEmpty) {
      return;
    }
    final qtyIdx = _resolveCustomQtyIndex();
    final rateIdx = _resolveCustomRateIndex();
    final amountIdx = _resolveCustomAmountIndex();
    if (qtyIdx < 0 || rateIdx < 0 || amountIdx < 0) return;

    for (final row in _customRows) {
      if (row.cells.length <= amountIdx) continue;
      final qty = row.cells.length > qtyIdx
          ? _parseCustomCellAmount(row.cells[qtyIdx].text)
          : 0;
      final rate = row.cells.length > rateIdx
          ? _parseCustomCellAmount(row.cells[rateIdx].text)
          : 0;
      final amount = qty * rate;
      // Keep manual amount entries when qty/rate are not provided.
      if (qty > 0 && rate > 0) {
        row.cells[amountIdx].text = amount.toStringAsFixed(0);
      }
    }
  }

  void _onCustomCellChanged(CustomQuotationRow row, int colIndex, String _) {
    if (!_customAutoCalculator) {
      setState(() {});
      return;
    }

    final qtyIdx = _resolveCustomQtyIndex();
    final rateIdx = _resolveCustomRateIndex();
    final amountIdx = _resolveCustomAmountIndex();

    if (qtyIdx >= 0 &&
        rateIdx >= 0 &&
        amountIdx >= 0 &&
        (colIndex == qtyIdx || colIndex == rateIdx)) {
      final qty = row.cells.length > qtyIdx
          ? _parseCustomCellAmount(row.cells[qtyIdx].text)
          : 0;
      final rate = row.cells.length > rateIdx
          ? _parseCustomCellAmount(row.cells[rateIdx].text)
          : 0;
      final amount = qty * rate;
      if (row.cells.length > amountIdx) {
        if (qty > 0 && rate > 0) {
          row.cells[amountIdx].text = amount.toStringAsFixed(0);
        }
      }
    }

    setState(() {});
  }

  double _customQuotationTotal() {
    if (_customHeaders.isEmpty || _customRows.isEmpty) return 0;
    final qtyIdx = _resolveCustomQtyIndex();
    final rateIdx = _resolveCustomRateIndex();
    final amountIdx = _resolveCustomAmountIndex();
    if (_customAutoCalculator && qtyIdx >= 0 && rateIdx >= 0) {
      double computed = 0;
      for (final row in _customRows) {
        final qty = row.cells.length > qtyIdx
            ? _parseCustomCellAmount(row.cells[qtyIdx].text)
            : 0;
        final rate = row.cells.length > rateIdx
            ? _parseCustomCellAmount(row.cells[rateIdx].text)
            : 0;
        if (qty > 0 && rate > 0) {
          computed += qty * rate;
          continue;
        }
        if (row.cells.length > amountIdx) {
          computed += _parseCustomCellAmount(row.cells[amountIdx].text);
        }
      }
      return computed;
    }

    final totalCol = _resolveCustomAmountIndex();
    double total = 0;
    for (final row in _customRows) {
      if (row.cells.length > totalCol) {
        total += _parseCustomCellAmount(row.cells[totalCol].text);
      }
    }
    return total;
  }

  double _effectiveCustomQuotationTotal() {
    final manualRaw = _customTotalOverrideCtrl.text.trim();
    if (manualRaw.isNotEmpty) {
      return _parseCustomCellAmount(manualRaw);
    }
    return _customQuotationTotal();
  }

  pw.Widget _buildCustomPdfTable(PdfColor navyColor) {
    final isSingleColumnMode = _customHeaders.length == 1;
    final singleHeaderText = _customHeaders.isNotEmpty
        ? (_customHeaders.first.text.trim().isEmpty
            ? 'Description'
            : _customHeaders.first.text.trim())
        : 'Description';

    pw.Widget cell(String text,
        {required int col,
        required List<pw.TextAlign> aligns,
        bool isHeader = false,
        bool isLastRow = false,
        double fontSize = 9.5}) {
      return pw.Container(
        decoration: isHeader
            ? pw.BoxDecoration(color: navyColor)
            : (!isLastRow
                ? const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(
                            color: PdfColors.grey200, width: 0.5)))
                : null),
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: _buildPdfFormattedText(
          text,
          fontSize: fontSize,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
          textAlign: aligns[col],
        ),
      );
    }

    if (isSingleColumnMode) {
      final headers = <String>['S.No', singleHeaderText];
      final rows = _customRows.asMap().entries.map((entry) {
        final index = entry.key;
        final r = entry.value;
        final cellValue = r.cells.isNotEmpty ? r.cells.first.text.trim() : '';
        final label = r.labelCtrl.text.trim();
        final detail = r.detailCtrl.text.trim();
        final description = cellValue.isNotEmpty
            ? cellValue
            : [label, detail].where((e) => e.isNotEmpty).join('\n');
        return <String>[
          '${index + 1}',
          description,
        ];
      }).toList();
      const aligns = [pw.TextAlign.center, pw.TextAlign.left];

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(0.8),
          1: const pw.FlexColumnWidth(7.2),
        },
        children: [
          pw.TableRow(
            children: headers
                .asMap()
                .entries
                .map((entry) => cell(entry.value,
                    col: entry.key, aligns: aligns, isHeader: true))
                .toList(),
          ),
          ...rows.asMap().entries.map((rowEntry) {
            final isLast = rowEntry.key == rows.length - 1;
            final row = rowEntry.value;
            return pw.TableRow(
              children: row
                  .asMap()
                  .entries
                  .map((entry) => cell(entry.value,
                      col: entry.key, aligns: aligns, isLastRow: isLast))
                  .toList(),
            );
          }),
        ],
      );
    }

    final visibleCustomHeaders = _customHeaders.skip(1).toList();
    final headers = <String>[
      'S.No',
      _customRowHeader.trim().isEmpty ? 'Row' : _customRowHeader.trim(),
      ...visibleCustomHeaders
          .map((h) => h.text.trim().isEmpty ? 'Column' : h.text.trim())
    ];
    final rows = _customRows.asMap().entries.map((entry) {
      final index = entry.key;
      final r = entry.value;
      final label =
          r.labelCtrl.text.trim().isEmpty ? 'Item' : r.labelCtrl.text.trim();
      final detail = r.detailCtrl.text.trim();
      final firstCell = detail.isEmpty ? label : '$label\n$detail';
      final values = r.cells.map((c) => c.text).toList();
      while (values.length < _customHeaders.length) {
        values.add('');
      }
      return <String>[
        '${index + 1}',
        firstCell,
        ...values.skip(1).take(visibleCustomHeaders.length)
      ];
    }).toList();

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.8),
      1: const pw.FlexColumnWidth(3),
    };
    for (var i = 2; i < headers.length; i++) {
      columnWidths[i] = const pw.FlexColumnWidth(2);
    }

    final aligns = <int, pw.Alignment>{
      0: pw.Alignment.center,
      1: pw.Alignment.centerLeft
    };
    for (var i = 2; i < headers.length; i++) {
      aligns[i] = pw.Alignment.centerLeft;
    }

    final textAligns = <pw.TextAlign>[
      pw.TextAlign.center,
      pw.TextAlign.left,
      ...List.generate(headers.length - 2, (_) => pw.TextAlign.left),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: columnWidths,
      children: [
        pw.TableRow(
          children: headers
              .asMap()
              .entries
              .map((entry) => cell(entry.value,
                  col: entry.key, aligns: textAligns, isHeader: true))
              .toList(),
        ),
        ...rows.asMap().entries.map((rowEntry) {
          final isLast = rowEntry.key == rows.length - 1;
          final row = rowEntry.value;
          return pw.TableRow(
            children: row
                .asMap()
                .entries
                .map((entry) => cell(entry.value,
                    col: entry.key, aligns: textAligns, isLastRow: isLast))
                .toList(),
          );
        }),
      ],
    );
  }

  // ── Custom Material Dialog ───────────────────────────────────────────────

  void _addCustomMaterial() {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1.000');
    final rateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Custom Material',
            style: TextStyle(
                color: Color(0xFF1A3A5C), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nameCtrl, 'Material Name', 'e.g. Marble, Wood',
                TextInputType.text),
            const SizedBox(height: 12),
            _dialogField(
                unitCtrl, 'Unit', 'e.g. Sqft, Kg, Bags', TextInputType.text),
            const SizedBox(height: 12),
            _dialogField(qtyCtrl, 'Qty per Sqft', 'e.g. 1.050',
                const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            _dialogField(rateCtrl, 'Rate per Unit (PKR)', 'e.g. 250',
                TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3A5C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (nameCtrl.text.isEmpty || rateCtrl.text.isEmpty) return;
              final item = MaterialItem(
                id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text,
                unit: unitCtrl.text.isEmpty ? 'Unit' : unitCtrl.text,
                qtyPerSqFt: double.tryParse(qtyCtrl.text) ?? 1.0,
                rate: double.tryParse(rateCtrl.text) ?? 0,
                isCustom: true,
              );
              setState(() => _materials.add(item));
              _saveMaterials();
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Shows a simple dialog to rename a field label.
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
            hintText: 'e.g. To, Supply, Subject…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 2),
            ),
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
                  borderRadius: BorderRadius.circular(8)),
            ),
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

  /// A form field with an editable label — tap the pencil icon to rename.
  Widget _editableLabeledField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
    VoidCallback onRename,
  ) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon,
            size: 14, color: const Color(0xFF1A3A5C).withValues(alpha: 0.6)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A3A5C),
            )),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRename,
          child: Tooltip(
            message: 'Rename label',
            child: Icon(Icons.edit_outlined,
                size: 13,
                color: const Color(0xFFF5A623).withValues(alpha: 0.8)),
          ),
        ),
      ]),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 2),
          ),
        ),
      ),
    ]);
  }

  Widget _dialogField(TextEditingController ctrl, String label, String hint,
      TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _clientCtrl.dispose();
    _subjectCtrl.dispose();
    _descriptionCtrl.dispose();
    _projectCtrl.dispose();
    _locationCtrl.dispose();
    _areaCtrl.dispose();
    _foundationDescCtrl.dispose();
    _foundationCostCtrl.dispose();
    for (final a in _customAddons) {
      a.dispose();
    }
    for (final h in _customHeaders) {
      h.dispose();
    }
    for (final r in _customRows) {
      r.dispose();
    }
    _customTotalOverrideCtrl.dispose();
    for (final m in _materials) {
      m.dispose();
    }
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.startInCustomMode) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Custom Quotation'),
          backgroundColor: const Color(0xFF1A3A5C),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_hasSavedQuotation)
              IconButton(
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: 'Load Last Quotation',
                onPressed: _loadQuotation,
              ),
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save Quotation',
              onPressed: _saveQuotation,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildCustomQuotationEditor(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saveQuotation,
                icon: const Icon(Icons.save_outlined, color: Color(0xFF1A3A5C)),
                label: const Text('Save This Quotation',
                    style: TextStyle(
                        color: Color(0xFF1A3A5C), fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: Color(0xFF1A3A5C)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatePdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Generate PDF on Letterhead',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _previewPdf,
                icon: const Icon(Icons.visibility_outlined,
                    color: Color(0xFF1A3A5C)),
                label: const Text('Preview PDF',
                    style: TextStyle(
                        color: Color(0xFF1A3A5C), fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: Color(0xFF1A3A5C)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showSummary,
                icon: const Icon(Icons.copy_outlined, color: Color(0xFF1A3A5C)),
                label: const Text('Copy Text Quotation',
                    style: TextStyle(color: Color(0xFF1A3A5C))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: Color(0xFF1A3A5C)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Cost Estimator'),
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasSavedQuotation)
            IconButton(
              icon: const Icon(Icons.folder_open_outlined),
              tooltip: 'Load Last Quotation',
              onPressed: _loadQuotation,
            ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save Quotation',
            onPressed: _saveQuotation,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFFF5A623),
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFFF5A623),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Details'),
            Tab(
                icon: Icon(Icons.price_change_outlined, size: 18),
                text: 'Rates'),
            Tab(
                icon: Icon(Icons.summarize_outlined, size: 18),
                text: 'Results'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildDetailsTab(),
          _buildRatesTab(),
          _buildResultsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _calculate,
        backgroundColor: const Color(0xFFF5A623),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.calculate_outlined),
        label: const Text('Calculate',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Tab 1: Project Details ───────────────────────────────────────────────

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Load banner ───────────────────────────────────────────────
          if (_hasSavedQuotation)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A5C).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF1A3A5C).withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.history, color: Color(0xFF1A3A5C), size: 18),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('You have a saved quotation.',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF1A3A5C)))),
                TextButton(
                  onPressed: _loadQuotation,
                  child: const Text('Load',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3A5C))),
                ),
              ]),
            ),

          // ── Client & Project ──────────────────────────────────────────
          _sectionCard('Client & Project', [
            Row(children: [
              const Icon(Icons.info_outline, size: 12, color: Colors.grey),
              const SizedBox(width: 6),
              Flexible(
                  child: Text('Tap the pencil ✏ next to any label to rename it',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500))),
            ]),
            const SizedBox(height: 12),
            _editableLabeledField(
              _clientCtrl,
              _labelClient,
              'e.g. Mr. Ahmed Khan',
              Icons.person_outline,
              () => _renameLabel(
                  _labelClient, (v) => setState(() => _labelClient = v)),
            ),
            const SizedBox(height: 12),
            _editableLabeledField(
              _subjectCtrl,
              _labelSubject,
              'e.g. Civil Works Quotation',
              Icons.subject_outlined,
              () => _renameLabel(
                  _labelSubject, (v) => setState(() => _labelSubject = v)),
            ),
            const SizedBox(height: 12),
            _editableLabeledField(
              _projectCtrl,
              _labelProject,
              'e.g. Residential House',
              Icons.home_work_outlined,
              () => _renameLabel(
                  _labelProject, (v) => setState(() => _labelProject = v)),
            ),
            const SizedBox(height: 12),
            _editableLabeledField(
              _locationCtrl,
              _labelLocation,
              'e.g. Lahore, Islamabad',
              Icons.location_on_outlined,
              () => _renameLabel(
                  _labelLocation, (v) => setState(() => _labelLocation = v)),
            ),
          ]),
          const SizedBox(height: 14),

          // ── Area & Scale ──────────────────────────────────────────────
          _sectionCard('Area & Scale', [
            _numberField(_areaCtrl, 'Built-up Area (Square Feet)', 'e.g. 2000',
                Icons.square_foot),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _counterField(
                      'Floors',
                      _floors,
                      () => setState(() {
                            if (_floors > 1) _floors--;
                            _autoCalc();
                          }),
                      () => setState(() {
                            if (_floors < 20) _floors++;
                            _autoCalc();
                          }))),
              const SizedBox(width: 12),
              Expanded(
                  child: _counterField(
                      'Rooms',
                      _rooms,
                      () => setState(() {
                            if (_rooms > 0) _rooms--;
                          }),
                      () => setState(() => _rooms++))),
              const SizedBox(width: 12),
              Expanded(
                  child: _counterField(
                      'Bathrooms',
                      _bathrooms,
                      () => setState(() {
                            if (_bathrooms > 0) _bathrooms--;
                          }),
                      () => setState(() => _bathrooms++))),
            ]),
          ]),
          const SizedBox(height: 14),

          // ── Project Type ──────────────────────────────────────────────
          _sectionCard('Project Type', [
            ...['Grey Structure', 'Standard', 'Premium', 'Custom / Other']
                .map((type) {
              final isSelected = _projectType == type;
              final Color c = type == 'Grey Structure'
                  ? Colors.grey.shade700
                  : type == 'Standard'
                      ? const Color(0xFF2196F3)
                      : type == 'Premium'
                          ? const Color(0xFFF5A623)
                          : const Color(0xFF7B2FBE);
              return GestureDetector(
                onTap: () => setState(() => _projectType = type),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? c.withValues(alpha: 0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected ? c : Colors.grey.shade300,
                        width: isSelected ? 2 : 1),
                  ),
                  child: Row(children: [
                    Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected ? c : Colors.grey,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(type,
                        style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? c : Colors.black87)),
                    const Spacer(),
                    if (type != 'Custom / Other')
                      Text(
                        type == 'Grey Structure'
                            ? '~0.25 M/sqft'
                            : type == 'Standard'
                                ? '~0.40 M/sqft'
                                : '~0.60 M/sqft',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                  ]),
                ),
              );
            }),
          ]),
          const SizedBox(height: 14),

          // ── Foundation Type ───────────────────────────────────────────
          _sectionCard('Foundation Type', [
            ...['Normal Strip', 'Raft Foundation', 'Pile Foundation', 'Custom']
                .map((f) {
              final isSelected = _foundation == f;
              return GestureDetector(
                onTap: () => setState(() {
                  _foundation = f;
                  _autoCalc();
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1A3A5C).withValues(alpha: 0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1A3A5C)
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? const Color(0xFF1A3A5C)
                                  : Colors.grey,
                              size: 20),
                          const SizedBox(width: 10),
                          Text(f == 'Custom' ? 'Custom Foundation' : f,
                              style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFF1A3A5C)
                                      : Colors.black87)),
                          if (f == 'Custom') ...[
                            const Spacer(),
                            Text('manual cost',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ]),
                        // Expand custom fields when selected
                        if (f == 'Custom' && isSelected) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _foundationDescCtrl,
                            decoration: InputDecoration(
                              hintText:
                                  'Foundation description (e.g. Bored Pile, Deep Raft…)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF1A3A5C), width: 2)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Expanded(
                              flex: 1,
                              child: Text('Cost:',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A3A5C))),
                            ),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _foundationCostCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*'))
                                ],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  suffixText: 'Million PKR',
                                  suffixStyle: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF1A3A5C), width: 2)),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ]),
                ),
              );
            }),
          ]),
          const SizedBox(height: 14),

          // ── Extras / Additional Works ─────────────────────────────────
          _sectionCard('Extras / Additional Works', [
            _extraCheckbox(
                'Basement',
                _hasBasement,
                Icons.foundation,
                (v) => setState(() {
                      _hasBasement = v!;
                      _autoCalc();
                    }),
                '~40% of base cost'),
            _extraCheckbox(
                'Boundary Wall',
                _hasBoundaryWall,
                Icons.fence,
                (v) => setState(() {
                      _hasBoundaryWall = v!;
                      _autoCalc();
                    }),
                '~0.25 Million PKR'),
            _extraCheckbox(
                'Car Porch',
                _hasCarPorch,
                Icons.garage_outlined,
                (v) => setState(() {
                      _hasCarPorch = v!;
                      _autoCalc();
                    }),
                '~200 sqft at 50% rate'),
            _extraCheckbox(
                'Swimming Pool',
                _hasPool,
                Icons.pool,
                (v) => setState(() {
                      _hasPool = v!;
                      _autoCalc();
                    }),
                '~1.20 Million PKR'),
            _extraCheckbox(
                'Servant Quarter',
                _hasServantQuarter,
                Icons.cottage_outlined,
                (v) => setState(() {
                      _hasServantQuarter = v!;
                      _autoCalc();
                    }),
                '~150 sqft at 65% rate'),

            // ── Custom Add-ons (multiple) ──────────────────────────────
            const Divider(height: 20),
            Row(children: [
              const Icon(Icons.add_circle_outline,
                  size: 18, color: Color(0xFF7B2FBE)),
              const SizedBox(width: 8),
              const Text('Custom Add-ons',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF7B2FBE))),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  final addon = CustomAddon();
                  addon.costCtrl.addListener(_autoCalc);
                  setState(() => _customAddons.add(addon));
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7B2FBE)),
              ),
            ]),
            Text('Add any custom work items with a fixed cost',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ..._customAddons.asMap().entries.map((entry) {
              final idx = entry.key;
              final addon = entry.value;
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2FBE).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF7B2FBE).withValues(alpha: 0.25)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Item ${idx + 1}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7B2FBE))),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            addon.dispose();
                            setState(() {
                              _customAddons.removeAt(idx);
                              _autoCalc();
                            });
                          },
                          child: const Icon(Icons.close,
                              size: 18, color: Colors.red),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      TextField(
                        controller: addon.nameCtrl,
                        decoration: InputDecoration(
                          hintText:
                              'Work description (e.g. Generator Room, Lift…)',
                          prefixIcon: const Icon(Icons.construction_outlined,
                              color: Color(0xFF7B2FBE), size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide: BorderSide(
                                  color: Color(0xFF7B2FBE), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: addon.costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'))
                        ],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixIcon: const Icon(Icons.attach_money,
                              color: Color(0xFF7B2FBE), size: 20),
                          suffixText: 'Million PKR',
                          suffixStyle:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                              borderSide: BorderSide(
                                  color: Color(0xFF7B2FBE), width: 2)),
                        ),
                      ),
                    ]),
              );
            }),
          ]),

          const SizedBox(height: 20),

          // Closing section always visible on Details tab
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A5C).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF1A3A5C).withValues(alpha: 0.2)),
            ),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.verified_outlined,
                        size: 16, color: Color(0xFF1A3A5C)),
                    SizedBox(width: 6),
                    Text('From FnF International',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A3A5C),
                            fontSize: 13)),
                  ]),
                  Divider(height: 16),
                  Text(
                    'Looking forward for your positive response and we hope that this is the start of a faithful working relationship between us.',
                    style: TextStyle(
                        fontSize: 12, height: 1.5, color: Colors.black87),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'In case of confirmation of order 80% will be advance.',
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                  SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Thank You,',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          Text('Ajmal Khan Jadoon,',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A3A5C))),
                          Text('CEO',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          Text('Friend & Friends International',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ]),
                  ),
                  Divider(height: 16),
                  Text(
                      'Head Office: House CB-301, 1st Floor, Street 2, Afshan Colony, Rawalpindi Cantt',
                      style: TextStyle(
                          fontSize: 10, color: Colors.black54, height: 1.5)),
                  Text(
                      'Branch Office: House 310, Lower Khalilzai, Garhi Pana Chowk, Nawan Shehr Abbottabad.',
                      style: TextStyle(
                          fontSize: 10, color: Colors.black54, height: 1.5)),
                  Text('Cell: 0311-5177747',
                      style: TextStyle(
                          fontSize: 10, color: Colors.black54, height: 1.5)),
                  Text('Email: fnfpvtltd@gmail.com',
                      style: TextStyle(
                          fontSize: 10, color: Colors.black54, height: 1.5)),
                ]),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Tab 2: Material Rates ────────────────────────────────────────────────

  Widget _buildRatesTab() {
    return Column(
      children: [
        Container(
          color: const Color(0xFF1A3A5C),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.white60, size: 16),
            const SizedBox(width: 8),
            const Expanded(
                child: Text(
              'Set your own rates — saved automatically for next time',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            )),
            TextButton.icon(
              onPressed: () => setState(() {
                for (final m in _materials) {
                  m.dispose();
                }
                _materials = _defaultMaterials();
                _saveMaterials();
              }),
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
              label: const Text('Reset',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: _materials.length + 1,
            itemBuilder: (ctx, i) {
              if (i == _materials.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: _addCustomMaterial,
                    icon: const Icon(Icons.add, color: Color(0xFF1A3A5C)),
                    label: const Text('Add Custom Material',
                        style: TextStyle(color: Color(0xFF1A3A5C))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFF1A3A5C), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                );
              }
              return _materialRateCard(_materials[i]);
            },
          ),
        ),
      ],
    );
  }

  Widget _materialRateCard(MaterialItem m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: m.enabled
                ? const Color(0xFF1A3A5C).withValues(alpha: 0.15)
                : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Switch(
              value: m.enabled,
              activeThumbColor: const Color(0xFF1A3A5C),
              onChanged: (v) => setState(() {
                m.enabled = v;
                _saveMaterials();
                _autoCalc();
              }),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: m.isCustom
                  ? TextField(
                      controller: m.nameCtrl,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3A5C)),
                      decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Material name'),
                      onChanged: (_) => _saveMaterials(),
                    )
                  : Text(m.nameCtrl.text,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: m.enabled
                              ? const Color(0xFF1A3A5C)
                              : Colors.grey)),
            ),
            if (m.isCustom)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: () => setState(() {
                  m.dispose();
                  _materials.remove(m);
                  _saveMaterials();
                }),
              ),
          ]),
          if (m.enabled) ...[
            const Divider(height: 8),
            Row(children: [
              Expanded(
                  child: _rateField(
                controller: m.qtyCtrl,
                label: 'Qty / Sqft',
                suffix: m.unit,
                onChanged: (_) {
                  _saveMaterials();
                  _autoCalc();
                },
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _rateField(
                controller: m.rateCtrl,
                label: 'Rate / ${m.unit}',
                suffix: 'PKR',
                onChanged: (_) {
                  _saveMaterials();
                  _autoCalc();
                },
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Per Sqft',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        'PKR ${(m.qtyPerSqFt * m.rate).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A3A5C),
                            fontSize: 13),
                      ),
                    ]),
              )),
            ]),
          ],
        ]),
      ),
    );
  }

  // ── Tab 3: Results ───────────────────────────────────────────────────────

  Widget _buildResultsTab() {
    if (!_calculated && !_customQuotationMode) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.calculate_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Fill in Project Details and tap',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFF5A623),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Calculate',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _customQuotationMode = true),
            icon: const Icon(Icons.grid_on_outlined),
            label: const Text('Use Custom Quotation'),
          ),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.tune, color: Color(0xFF1A3A5C), size: 18),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Custom Quotation Mode',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1A3A5C)))),
            Switch(
                value: _customQuotationMode,
                activeThumbColor: const Color(0xFF1A3A5C),
                onChanged: (v) => setState(() => _customQuotationMode = v)),
          ]),
        ),

        // Project info header
        if (!_customQuotationMode &&
            (_clientCtrl.text.isNotEmpty || _projectCtrl.text.isNotEmpty))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_clientCtrl.text.isNotEmpty)
                _infoRow(_labelClient, _clientCtrl.text, Icons.person_outline),
              if (_projectCtrl.text.isNotEmpty)
                _infoRow(
                    _labelProject, _projectCtrl.text, Icons.home_work_outlined),
              if (_locationCtrl.text.isNotEmpty)
                _infoRow(_labelLocation, _locationCtrl.text,
                    Icons.location_on_outlined),
              _infoRow(
                  'Area',
                  '${_areaCtrl.text} sqft × $_floors floors = ${_effectiveArea.toStringAsFixed(0)} effective sqft',
                  Icons.square_foot),
            ]),
          ),

        // Total cost card
        if (!_customQuotationMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A3A5C), Color(0xFF0D2D4F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF1A3A5C).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Column(children: [
              const Text('Total Estimated Cost',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(_formatPKR(_totalCost),
                  style: const TextStyle(
                      color: Color(0xFFF5A623),
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('PKR ${_basePerSqFt.toStringAsFixed(0)} per sqft',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),
        if (!_customQuotationMode) const SizedBox(height: 14),

        // Summary stats
        if (!_customQuotationMode)
          Row(children: [
            _statCard(
                'Base Cost', _formatPKR(_baseCost), const Color(0xFF1A3A5C)),
            const SizedBox(width: 10),
            _statCard(
                'Extras', _formatPKR(_extrasCost), const Color(0xFFF5A623)),
          ]),
        if (!_customQuotationMode) const SizedBox(height: 14),

        // Table / List toggle
        if (!_customQuotationMode)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.table_chart_outlined,
                  color: Color(0xFF1A3A5C), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Show as Table',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1A3A5C)))),
              Switch(
                  value: _useTable,
                  activeThumbColor: const Color(0xFF1A3A5C),
                  onChanged: (v) => setState(() => _useTable = v)),
            ]),
          ),

        if (_customQuotationMode)
          _buildCustomQuotationEditor()
        else if (_useTable)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(children: [
              Container(
                decoration: const BoxDecoration(
                    color: Color(0xFF1A3A5C),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12))),
                child: const Row(children: [
                  Expanded(
                      flex: 1,
                      child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('S.No',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                              textAlign: TextAlign.center))),
                  Expanded(
                      flex: 4,
                      child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('Description',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)))),
                  Expanded(
                      flex: 3,
                      child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('Qty × Rate',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)))),
                  Expanded(
                      flex: 3,
                      child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('Amount',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                              textAlign: TextAlign.right))),
                ]),
              ),
              ..._breakdown.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Container(
                  color: idx.isEven ? Colors.white : Colors.grey.shade50,
                  child: Row(children: [
                    Expanded(
                        flex: 1,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            child: Text('${idx + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Color(0xFF1A3A5C)),
                                textAlign: TextAlign.center))),
                    Expanded(
                        flex: 4,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            child: Text(item['name'].toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12)))),
                    Expanded(
                        flex: 3,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            child: Text(
                                '${(item['qty'] as double).toStringAsFixed(1)} ${item['unit']}\n× PKR ${(item['rate'] as double).toStringAsFixed(0)}',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11)))),
                    Expanded(
                        flex: 3,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            child: Text(_formatPKR(item['cost'] as double),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A3A5C),
                                    fontSize: 12),
                                textAlign: TextAlign.right))),
                  ]),
                );
              }),
              Container(
                decoration: BoxDecoration(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12))),
                child: Row(children: [
                  const Expanded(
                      flex: 7,
                      child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('Base Material Cost',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A3A5C))))),
                  Expanded(
                      flex: 3,
                      child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(_formatPKR(_baseCost),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A3A5C)),
                              textAlign: TextAlign.right))),
                ]),
              ),
            ]),
          )
        else
          _sectionCard('Material Breakdown', [
            ..._breakdown.map((item) {
              final pct =
                  _baseCost > 0 ? (item['cost'] as double) / _baseCost : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(item['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A3A5C)))),
                        Text(_formatPKR(item['cost'] as double),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A3A5C))),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          '${(item['qty'] as double).toStringAsFixed(1)} ${item['unit']} × PKR ${(item['rate'] as double).toStringAsFixed(0)}',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11)),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.toDouble(),
                          backgroundColor: Colors.grey.shade100,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFF5A623)),
                          minHeight: 6,
                        ),
                      ),
                    ]),
              );
            }),
          ]),

        // Extras breakdown
        if (!_customQuotationMode && _extrasCost > 0) ...[
          const SizedBox(height: 14),
          _sectionCard('Additional Works', [
            if (_hasBasement)
              _extraRow(
                  'Basement',
                  _formatPKR((double.tryParse(_areaCtrl.text) ?? 0) *
                      _basePerSqFt *
                      0.40)),
            if (_hasBoundaryWall)
              _extraRow('Boundary Wall', _formatPKR(250000)),
            if (_hasCarPorch)
              _extraRow('Car Porch', _formatPKR(200 * _basePerSqFt * 0.50)),
            if (_hasPool) _extraRow('Swimming Pool', _formatPKR(1200000)),
            if (_hasServantQuarter)
              _extraRow(
                  'Servant Quarter', _formatPKR(150 * _basePerSqFt * 0.65)),
            if (_foundation == 'Custom')
              _extraRow(
                _foundationDescCtrl.text.isNotEmpty
                    ? _foundationDescCtrl.text
                    : 'Custom Foundation',
                _formatPKR(
                    (double.tryParse(_foundationCostCtrl.text) ?? 0) * 1000000),
              ),
            for (final a in _customAddons)
              _extraRow(a.label, _formatPKR(a.costPKR)),
          ]),
        ],

        const SizedBox(height: 16),

        // Disclaimer
        if (!_customQuotationMode)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'This is an estimated cost based on your entered rates. Final cost may vary based on site conditions, design changes, and material price fluctuations.',
                    style: TextStyle(
                        color: Colors.brown, fontSize: 12, height: 1.4),
                  )),
                ]),
          ),
        if (!_customQuotationMode) const SizedBox(height: 16),

        // Closing section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A5C).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF1A3A5C).withValues(alpha: 0.2)),
          ),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.verified_outlined,
                      size: 16, color: Color(0xFF1A3A5C)),
                  SizedBox(width: 6),
                  Text('Included in Every Quotation',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3A5C),
                          fontSize: 13)),
                ]),
                Divider(height: 16),
                Text(
                  'Looking forward for your positive response and we hope that this is the start of a faithful working relationship between us.',
                  style: TextStyle(
                      fontSize: 12, height: 1.5, color: Colors.black87),
                ),
                SizedBox(height: 8),
                Text(
                  'In case of confirmation of order 80% will be advance.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Thank You,',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('Ajmal Khan Jadoon,',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A3A5C))),
                        Text('CEO',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('Friend & Friends International',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54)),
                      ]),
                ),
                Divider(height: 16),
                Text(
                    'Head Office: House CB-301, 1st Floor, Street 2, Afshan Colony, Rawalpindi Cantt',
                    style: TextStyle(
                        fontSize: 10, color: Colors.black54, height: 1.5)),
                Text(
                    'Branch Office: House 310, Lower Khalilzai, Garhi Pana Chowk, Nawan Shehr Abbottabad.',
                    style: TextStyle(
                        fontSize: 10, color: Colors.black54, height: 1.5)),
                Text('Cell: 0311-5177747',
                    style: TextStyle(
                        fontSize: 10, color: Colors.black54, height: 1.5)),
                Text('Email: fnfpvtltd@gmail.com',
                    style: TextStyle(
                        fontSize: 10, color: Colors.black54, height: 1.5)),
              ]),
        ),
        const SizedBox(height: 16),

        // Save button (results tab)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _saveQuotation,
            icon: const Icon(Icons.save_outlined, color: Color(0xFF1A3A5C)),
            label: const Text('Save This Quotation',
                style: TextStyle(
                    color: Color(0xFF1A3A5C), fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Color(0xFF1A3A5C)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Generate PDF
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generatePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Generate PDF on Letterhead',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3A5C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _previewPdf,
            icon:
                const Icon(Icons.visibility_outlined, color: Color(0xFF1A3A5C)),
            label: const Text('Preview PDF',
                style: TextStyle(
                    color: Color(0xFF1A3A5C), fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Color(0xFF1A3A5C)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Copy text
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showSummary,
            icon: const Icon(Icons.copy_outlined, color: Color(0xFF1A3A5C)),
            label: const Text('Copy Text Quotation',
                style: TextStyle(color: Color(0xFF1A3A5C))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Color(0xFF1A3A5C)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  void _showSummary() {
    final summary = _generateSummary();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.description_outlined, color: Color(0xFF1A3A5C)),
          SizedBox(width: 8),
          Text('Full Quotation',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A3A5C))),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Text(summary,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12, height: 1.5)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: summary));
              Navigator.pop(ctx);
              _showSnack('Copied to clipboard!');
            },
            child: const Text('Copy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A5C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomQuotationEditor() {
    final isSingleColumnMode = _customHeaders.length == 1;

    return _sectionCard('Custom Quotation Table', [
      Text('Set your own column names, row labels, details, and cell values.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      const SizedBox(height: 10),
      Row(children: [
        const Text('Auto Calculator',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF1A3A5C))),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Auto-fills Amount = Qty x Rate',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ),
        Switch(
          value: _customAutoCalculator,
          activeThumbColor: const Color(0xFF1A3A5C),
          onChanged: (v) => setState(() {
            _customAutoCalculator = v;
            _recalculateAllCustomRowAmounts();
          }),
        ),
      ]),
      const SizedBox(height: 8),
      const Text('Quotation Info',
          style:
              TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A3A5C))),
      const SizedBox(height: 8),
      TextField(
        controller: _clientCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: _labelClient,
          isDense: true,
          suffixIcon: IconButton(
            tooltip: 'Rename heading',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _renameLabel(
                _labelClient, (v) => setState(() => _labelClient = v)),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _subjectCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: _labelSubject,
          isDense: true,
          suffixIcon: IconButton(
            tooltip: 'Rename heading',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _renameLabel(
                _labelSubject, (v) => setState(() => _labelSubject = v)),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _locationCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: _labelLocation,
          isDense: true,
          suffixIcon: IconButton(
            tooltip: 'Rename heading',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _renameLabel(
                _labelLocation, (v) => setState(() => _labelLocation = v)),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notes_rounded,
                    size: 14, color: Color(0xFF1A3A5C)),
                const SizedBox(width: 6),
                Text('Description',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.blueGrey.shade800)),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionCtrl,
              minLines: 2,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  color: Colors.black87, fontSize: 12, height: 1.3),
              decoration: InputDecoration(
                hintText:
                    'Use *bold*, _italic_, __underline__, ~strike~ in text',
                hintStyle:
                    TextStyle(color: Colors.blueGrey.shade300, fontSize: 11),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD6DBE3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD6DBE3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF1A3A5C), width: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        const Text('Columns',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF1A3A5C))),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _customHeaders.add(TextEditingController(
                  text: 'Column ${_customHeaders.length + 1}'));
              for (final r in _customRows) {
                r.ensureColumns(_customHeaders.length);
              }
            });
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Column'),
        ),
      ]),
      const SizedBox(height: 8),
      if (!isSingleColumnMode) ...[
        SizedBox(
          width: 180,
          child: TextFormField(
            initialValue: _customRowHeader,
            onChanged: (v) => setState(() => _customRowHeader = v),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Column 1 Name',
              hintText: 'Row',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _customHeaders.asMap().entries.where((entry) {
          return isSingleColumnMode || entry.key > 0;
        }).map((entry) {
          final i = entry.key;
          final ctrl = entry.value;
          return SizedBox(
            width: 150,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  onChanged: (_) => setState(() {
                    _recalculateAllCustomRowAmounts();
                  }),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Column ${i + 1}',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              if (_customHeaders.length > 1)
                IconButton(
                  onPressed: () {
                    setState(() {
                      final removed = _customHeaders.removeAt(i);
                      removed.dispose();
                      for (final r in _customRows) {
                        r.ensureColumns(_customHeaders.length);
                      }
                    });
                  },
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
            ]),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Text('Rows',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF1A3A5C))),
        const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() => _customRows
              .add(CustomQuotationRow(columnCount: _customHeaders.length))),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Row'),
        ),
      ]),
      ..._customRows.asMap().entries.map((entry) {
        final idx = entry.key;
        final row = entry.value;
        row.ensureColumns(_customHeaders.length);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Spacer(),
              if (_customRows.length > 1)
                IconButton(
                  onPressed: () {
                    setState(() {
                      row.dispose();
                      _customRows.removeAt(idx);
                    });
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                ),
            ]),
            const SizedBox(height: 8),
            if (!isSingleColumnMode) ...[
              TextField(
                controller: row.labelCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Row Label',
                  hintText: 'e.g. Cement, Labor, Paint Works',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: row.detailCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Details',
                  hintText: 'Optional detail line for this row',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: row.cells.asMap().entries.where((cellEntry) {
                return isSingleColumnMode || cellEntry.key > 0;
              }).map((cellEntry) {
                final colName = _customHeaders[cellEntry.key].text.trim();
                return SizedBox(
                  width: 150,
                  child: TextField(
                    controller: cellEntry.value,
                    onChanged: (v) =>
                        _onCustomCellChanged(row, cellEntry.key, v),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: colName.isEmpty
                          ? 'Column ${cellEntry.key + 1}'
                          : colName,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),
        );
      }),
      const SizedBox(height: 8),
      TextField(
        controller: _customTotalOverrideCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Manual Total (PKR)',
          hintText: 'Optional: set total directly without row amounts',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: _customTotalOverrideCtrl.text.trim().isNotEmpty
              ? IconButton(
                  tooltip: 'Clear manual total',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _customTotalOverrideCtrl.clear();
                  }),
                )
              : null,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A5C),
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Custom Quotation Total',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          Text(_formatPKR(_effectiveCustomQuotationTotal()),
              style: const TextStyle(
                  color: Color(0xFFF5A623), fontWeight: FontWeight.bold)),
        ]),
      )
    ]);
  }

  // ── Shared Widgets ───────────────────────────────────────────────────────

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1A3A5C))),
        const SizedBox(height: 4),
        Container(
            height: 2,
            width: 36,
            decoration: BoxDecoration(
                color: const Color(0xFFF5A623),
                borderRadius: BorderRadius.circular(1))),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }

  Widget _numberField(
      TextEditingController ctrl, String label, String hint, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A3A5C),
              fontSize: 13)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        ],
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF1A3A5C), size: 20),
          suffixText: 'sqft',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    ]);
  }

  Widget _counterField(
      String label, int value, VoidCallback dec, VoidCallback inc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300)),
      child: Column(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
              onTap: dec,
              child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A3A5C).withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.remove,
                      size: 16, color: Color(0xFF1A3A5C)))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('$value',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1A3A5C)))),
          GestureDetector(
              onTap: inc,
              child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A3A5C).withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.add,
                      size: 16, color: Color(0xFF1A3A5C)))),
        ]),
      ]),
    );
  }

  Widget _extraCheckbox(String label, bool value, IconData icon,
      ValueChanged<bool?> onChanged, String note) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF1A3A5C),
      contentPadding: EdgeInsets.zero,
      title: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF1A3A5C)),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
      subtitle: Text(note,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
    );
  }

  Widget _rateField(
      {required TextEditingController controller,
      required String label,
      required String suffix,
      required ValueChanged<String> onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        ],
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          suffixText: suffix,
          suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
          isDense: true,
          contentPadding: const EdgeInsets.all(10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 2)),
        ),
      ),
    ]);
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: const Color(0xFF1A3A5C)),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _extraRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        const Icon(Icons.check_circle_outline,
            size: 16, color: Color(0xFF1A3A5C)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF1A3A5C), fontWeight: FontWeight.w500))),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1A3A5C))),
      ]),
    );
  }
}
