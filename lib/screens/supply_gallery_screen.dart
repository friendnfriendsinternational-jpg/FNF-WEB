import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'supply_screen.dart';

class SupplyGalleryScreen extends StatefulWidget {
  const SupplyGalleryScreen({super.key});

  @override
  State<SupplyGalleryScreen> createState() => _SupplyGalleryScreenState();
}

class _SupplyGalleryScreenState extends State<SupplyGalleryScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('supply_gallery_v1');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        list.sort((a, b) {
          final aDate = DateTime.tryParse(a['savedAt'] ?? '') ?? DateTime(2000);
          final bDate = DateTime.tryParse(b['savedAt'] ?? '') ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
        setState(() {
          _orders = list;
          _loading = false;
        });
        return;
      } catch (_) {}
    }
    setState(() => _loading = false);
  }

  Future<void> _delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _orders.removeWhere((o) => o['id'] == id));
    await prefs.setString('supply_gallery_v1', jsonEncode(_orders));
    _showSnack('Order deleted');
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
    return d != null ? '${d.day}/${d.month}/${d.year}' : '';
  }

  String _fmtAmount(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)} M PKR';
    if (v >= 1000) return 'PKR ${(v / 1000).toStringAsFixed(1)}K';
    return 'PKR ${v.toStringAsFixed(0)}';
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _orders;
    final q = _search.toLowerCase();
    return _orders
        .where((o) =>
            (o['to'] ?? '').toLowerCase().contains(q) ||
            (o['subject'] ?? '').toLowerCase().contains(q) ||
            (o['ref'] ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Supply Orders'),
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Supply Order',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SupplyScreen()));
              _loadOrders();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by client, subject or reference…',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SupplyScreen()));
          _loadOrders();
        },
        backgroundColor: const Color(0xFF1A3A5C),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Order',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A3A5C)))
          : _filtered.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    final hasAny = _orders.isNotEmpty;
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
                hasAny ? Icons.search_off : Icons.local_shipping_outlined,
                size: 44,
                color: const Color(0xFF1A3A5C).withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text(
            hasAny ? 'No orders match your search' : 'No Supply Orders Yet',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3A5C)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            hasAny
                ? 'Try a different client name or reference.'
                : 'Tap the + button to create your first supply quotation.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade500, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) => _buildCard(_filtered[i]),
    );
  }

  Widget _buildCard(Map<String, dynamic> o) {
    final to = o['to'] as String? ?? '';
    final subject = o['subject'] as String? ?? '';
    final ref = o['ref'] as String? ?? '';
    final location = o['location'] as String? ?? '';
    final total = (o['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final date = _fmtDate(o['savedAt'] as String?);
    final items = (o['items'] as List?)?.length ?? 0;

    return Dismissible(
      key: Key(o['id'] as String),
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
      confirmDismiss: (_) async =>
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Delete Order?',
                  style: TextStyle(
                      color: Color(0xFF1A3A5C), fontWeight: FontWeight.bold)),
              content:
                  Text('Delete order${to.isNotEmpty ? ' for "$to"' : ''}?'),
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
          false,
      onDismissed: (_) => _delete(o['id'] as String),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => SupplyScreen(initialData: o)));
          _loadOrders();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF1A3A5C).withValues(alpha: 0.15)),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A5C).withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
                border: Border(
                    bottom: BorderSide(
                        color:
                            const Color(0xFF1A3A5C).withValues(alpha: 0.12))),
              ),
              child: Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A5C).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('SUPPLY ORDER',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3A5C),
                          letterSpacing: 0.5)),
                ),
                const Spacer(),
                if (ref.isNotEmpty) ...[
                  Icon(Icons.tag, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(ref,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.calendar_today_outlined,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(date,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios,
                    size: 13,
                    color: const Color(0xFF1A3A5C).withValues(alpha: 0.4)),
              ]),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      to.isNotEmpty
                          ? to
                          : (subject.isNotEmpty ? subject : 'Untitled Order'),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A3A5C)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subject.isNotEmpty && to.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(subject,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    const SizedBox(height: 10),
                    Row(children: [
                      _chip(
                          Icons.inventory_2_outlined,
                          '$items item${items == 1 ? '' : 's'}',
                          Colors.blueGrey),
                      if (location.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                            child: _chip(Icons.location_on_outlined, location,
                                Colors.blueGrey)),
                      ],
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0x121A3A5C), Color(0x10F5A623)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.local_shipping_outlined,
                            size: 16, color: Color(0xFF1A3A5C)),
                        const SizedBox(width: 8),
                        const Text('Grand Total',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF1A3A5C))),
                        const Spacer(),
                        Text(_fmtAmount(total),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A3A5C))),
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
          borderRadius: BorderRadius.circular(6)),
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
