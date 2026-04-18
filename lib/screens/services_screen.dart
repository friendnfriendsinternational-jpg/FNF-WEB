import 'package:flutter/material.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static const List<Map<String, dynamic>> _services = [
    {
      'title': 'Government Contracting',
      'icon': Icons.account_balance_outlined,
      'color': Color(0xFF1A3A5C),
      'bgColor': Color(0xFFE8F0FB),
      'description':
          'Execution of government and semi-government projects for defence, public sector, and institutional departments. Full compliance with approved specifications, BOQs, and timelines.',
      'features': [
        'Defence & Military Projects',
        'Public Sector Institutions',
        'BOQ-Based Estimation',
        'Compliance with Govt. Specs',
        'On-Time Delivery Guaranteed',
      ],
    },
    {
      'title': 'Construction & Building',
      'icon': Icons.foundation,
      'color': Color(0xFFD4380D),
      'bgColor': Color(0xFFFFF1EC),
      'description':
          'Complete construction solutions from residential and commercial buildings to civil works and turnkey projects — handled with quality and precision at every stage.',
      'features': [
        'Residential Construction',
        'Commercial & Institutional Buildings',
        'Civil & Structural Works',
        'Renovation, Repair & Maintenance',
        'Turnkey Construction Solutions',
      ],
    },
    {
      'title': 'General Order Supply (GOS)',
      'icon': Icons.inventory_2_outlined,
      'color': Color(0xFF7B2FBE),
      'bgColor': Color(0xFFF3E8FF),
      'description':
          'Reliable supply of construction materials, electrical and mechanical items, office furniture, safety equipment, and customized solutions for government departments.',
      'features': [
        'Construction Materials',
        'Electrical & Mechanical Items',
        'Office Furniture & Equipment',
        'Safety & Operational Supplies',
        'Customized Govt. Supply Solutions',
      ],
    },
    {
      'title': 'Interior Design & Fit-Out',
      'icon': Icons.design_services_outlined,
      'color': Color(0xFF1D7D4E),
      'bgColor': Color(0xFFE8F8EE),
      'description':
          'Professional interior design and fit-out services for offices, residences, and commercial or institutional spaces — covering space planning, finishing, and furnishing.',
      'features': [
        'Office Interior Design & Execution',
        'Residential Interior Solutions',
        'Commercial & Institutional Fit-Outs',
        'Space Planning & Finishing',
        'Furnishing Works',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Our Services'),
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1A3A5C),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What We Offer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Friend n Friends International delivers reliable, well-planned solutions for government and private clients.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final service = _services[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ServiceCard(service: service),
                  );
                },
                childCount: _services.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _TrustedClients(),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: _WhyChooseUs(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final Map<String, dynamic> service;

  const _ServiceCard({required this.service});

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final Color color = service['color'] as Color;
    final Color bgColor = service['bgColor'] as Color;
    final List<String> features = service['features'] as List<String>;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    service['icon'] as IconData,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    service['title'] as String,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: color,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['description'] as String,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Key Services:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustedClients extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const clients = [
      'DHPP — Dasu Hydropower Project',
      'Army School of Music',
      'Heavy Mechanical Complex (Texla)',
      'Havelian Ordinance Depot',
      'AFPGMI',
      'Special Services Group (SSG)',
      'Army Corps Ordnance',
      'AMC — Army Medical Corps',
      'FWO — Frontier Works Organization',
      'Army Corps of Engineers',
      'Frontier Force Regiment',
      'Baloch Regiment',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trusted by Leading Defence & Public Sector Institutions',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1A3A5C),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5A623),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: clients
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                const Color(0xFF1A3A5C).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                          color: Color(0xFF1A3A5C),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _WhyChooseUs extends StatelessWidget {
  const _WhyChooseUs();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A5C), Color(0xFF0D1F33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why Choose Friend n Friends International?',
            style: TextStyle(
              color: Color(0xFFF5A623),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _WhyItem(
            icon: Icons.verified_outlined,
            text: 'Trusted by top defence and government institutions',
          ),
          _WhyItem(
            icon: Icons.timer_outlined,
            text: 'Full compliance with BOQs and approved specifications',
          ),
          _WhyItem(
            icon: Icons.thumb_up_outlined,
            text: 'Quality materials and skilled craftsmanship',
          ),
          _WhyItem(
            icon: Icons.handshake_outlined,
            text: 'Transparent communication and long-term partnerships',
          ),
          _WhyItem(
            icon: Icons.support_agent_outlined,
            text: 'Dedicated support from planning to completion',
          ),
        ],
      ),
    );
  }
}

class _WhyItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WhyItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF5A623), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
