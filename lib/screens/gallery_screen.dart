import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'quotation_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('project_gallery_v1');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        // Sort newest first
        list.sort((a, b) {
          final aDate = DateTime.tryParse(a['savedAt'] ?? '') ?? DateTime(2000);
          final bDate = DateTime.tryParse(b['savedAt'] ?? '') ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
        setState(() {
          _projects = list;
          _loading = false;
        });
        return;
      } catch (_) {}
    }
    setState(() => _loading = false);
  }

  Future<void> _deleteProject(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _projects.removeWhere((p) => p['id'] == id));
    await prefs.setString('project_gallery_v1', jsonEncode(_projects));
    _showSnack('Project deleted');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _projects;
    final q = _search.toLowerCase();
    return _projects.where((p) {
      return (p['client'] ?? '').toLowerCase().contains(q) ||
          (p['project'] ?? '').toLowerCase().contains(q) ||
          (p['location'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'Grey Structure':
        return Colors.grey.shade700;
      case 'Standard':
        return const Color(0xFF2196F3);
      case 'Premium':
        return const Color(0xFFF5A623);
      default:
        return const Color(0xFF7B2FBE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Project Gallery'),
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by client, project or location…',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38, size: 20),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.10),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A3A5C)))
          : _filtered.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    final hasAny = _projects.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A5C).withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasAny ? Icons.search_off : Icons.folder_open_outlined,
              size: 44,
              color: const Color(0xFF1A3A5C).withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasAny ? 'No projects match your search' : 'No Saved Projects Yet',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3A5C)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            hasAny
                ? 'Try a different client name or location.'
                : 'Go to Cost Estimator, fill in the details,\ncalculate, and tap Save.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade500, height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (!hasAny) ...[
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Create a Quotation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A5C),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) => _buildCard(_filtered[i]),
    );
  }

  Widget _buildCard(Map<String, dynamic> p) {
    final client = p['client'] as String? ?? '';
    final project = p['project'] as String? ?? '';
    final location = p['location'] as String? ?? '';
    final area = p['area'] as String? ?? '';
    final floors = p['floors'] as int? ?? 1;
    final projectType = p['projectType'] as String? ?? 'Standard';
    final totalCostM = (p['totalCostM'] as num?)?.toDouble() ?? 0.0;
    final savedAt = _fmtDate(p['savedAt'] as String?);
    final color = _typeColor(projectType);

    // Extras summary
    final extras = <String>[];
    if (p['hasBasement'] == true) extras.add('Basement');
    if (p['hasBoundaryWall'] == true) extras.add('Boundary Wall');
    if (p['hasCarPorch'] == true) extras.add('Car Porch');
    if (p['hasPool'] == true) extras.add('Pool');
    if (p['hasServantQuarter'] == true) extras.add('Serv. Quarter');
    if (p['hasCustomAddon'] == true &&
        (p['customAddonName'] ?? '').isNotEmpty) {
      extras.add(p['customAddonName'] as String);
    }

    return Dismissible(
      key: Key(p['id'] as String),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text('Delete',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ]),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Delete Project?',
                    style: TextStyle(
                        color: Color(0xFF1A3A5C), fontWeight: FontWeight.bold)),
                content: Text(
                    'This will permanently delete "${client.isNotEmpty ? client : project}".',
                    style: const TextStyle(color: Colors.black87)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => _deleteProject(p['id'] as String),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuotationScreen(initialData: p),
              ));
          _loadProjects();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header stripe
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
                border: Border(
                    bottom: BorderSide(color: color.withValues(alpha: 0.15))),
              ),
              child: Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(projectType,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
                const Spacer(),
                Icon(Icons.calendar_today_outlined,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(savedAt,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios,
                    size: 13, color: color.withValues(alpha: 0.5)),
              ]),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client & project name
                    Text(
                      client.isNotEmpty
                          ? client
                          : (project.isNotEmpty ? project : 'Untitled Project'),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3A5C)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (project.isNotEmpty && client.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(project,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    const SizedBox(height: 10),

                    // Stats row
                    Row(children: [
                      _chip(Icons.square_foot, '$area sqft', Colors.blueGrey),
                      const SizedBox(width: 8),
                      _chip(
                          Icons.layers_outlined,
                          '$floors ${floors == 1 ? 'floor' : 'floors'}',
                          Colors.blueGrey),
                      if (location.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                            child: _chip(Icons.location_on_outlined, location,
                                Colors.blueGrey)),
                      ],
                    ]),

                    if (extras.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: extras
                              .map((e) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A3A5C)
                                          .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(e,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF1A3A5C),
                                            fontWeight: FontWeight.w500)),
                                  ))
                              .toList()),
                    ],

                    const SizedBox(height: 12),
                    // Divider + cost
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1A3A5C).withValues(alpha: 0.07),
                            color.withValues(alpha: 0.08)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calculate_outlined,
                            size: 16, color: Color(0xFF1A3A5C)),
                        const SizedBox(width: 8),
                        const Text('Total Estimated Cost',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF1A3A5C))),
                        const Spacer(),
                        Text(
                          '${totalCostM.toStringAsFixed(2)} M PKR',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                      ]),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
