import 'package:flutter/material.dart';
import 'quotation_screen.dart';
import 'services_screen.dart';
import 'contact_screen.dart';
import 'gallery_screen.dart';
import 'supply_screen.dart';
import 'supply_gallery_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A3A5C),
              Color(0xFF0D1F33),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Company Logo
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 110,
                        height: 110,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => const Icon(
                          Icons.construction,
                          size: 56,
                          color: Color(0xFF1A3A5C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Company Name
                  const Text(
                    'Friend n Friends International',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Partnering for Progress',
                    style: TextStyle(
                      color: Color(0xFFF5A623),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Building Dreams, Delivering Excellence',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'QUICK ACCESS',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Buttons
                  _HomeButton(
                    icon: Icons.calculate_outlined,
                    label: 'Project Estimater',
                    subtitle: 'Estimate your project cost',
                    color: const Color(0xFFF5A623),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const QuotationScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HomeButton(
                    icon: Icons.grid_view_outlined,
                    label: 'Custom Quotation',
                    subtitle: 'Create a fully custom table quotation',
                    color: const Color(0xFF7B2FBE),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const QuotationScreen(startInCustomMode: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HomeButton(
                    icon: Icons.business_outlined,
                    label: 'Our Services',
                    subtitle: 'Explore what we offer',
                    color: const Color(0xFF2196F3),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServicesScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HomeButton(
                    icon: Icons.contact_phone_outlined,
                    label: 'Contact Us',
                    subtitle: 'Reach out to our team',
                    color: const Color(0xFF4CAF50),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HomeButton(
                    icon: Icons.folder_special_outlined,
                    label: 'Project Gallery',
                    subtitle: 'View & manage saved projects',
                    color: const Color(0xFFE91E8C),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GalleryScreen(),
                      ),
                    ),
                  ),

                  // ── Supply Chain Section ──────────────────────────────
                  const SizedBox(height: 28),
                  Row(children: [
                    Expanded(
                        child: Divider(
                            color: Colors.white.withValues(alpha: 0.15),
                            thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('SUPPLY CHAIN',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Colors.white.withValues(alpha: 0.35))),
                    ),
                    Expanded(
                        child: Divider(
                            color: Colors.white.withValues(alpha: 0.15),
                            thickness: 1)),
                  ]),
                  const SizedBox(height: 16),

                  _HomeButton(
                    icon: Icons.local_shipping_outlined,
                    label: 'Supply Quotation',
                    subtitle: 'Create a new supply order quotation',
                    color: const Color(0xFF00897B),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupplyScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HomeButton(
                    icon: Icons.inventory_2_outlined,
                    label: 'Supply Orders',
                    subtitle: 'View & manage supply records',
                    color: const Color(0xFF5C6BC0),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupplyGalleryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Trusted Clients Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          'TRUSTED BY',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ClientBadge('DHPP'),
                            _ClientBadge('Army School of Music'),
                            _ClientBadge('HMC Texla'),
                            _ClientBadge('AFPGMI'),
                            _ClientBadge('SSG'),
                            _ClientBadge('FWO'),
                            _ClientBadge('Army Corps of Engineers'),
                            _ClientBadge('AMC'),
                            _ClientBadge('Baloch Regiment'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(value: 'Govt.', label: 'Contractor'),
                        _StatDivider(),
                        _StatItem(value: '12+', label: 'Defence Clients'),
                        _StatDivider(),
                        _StatItem(value: '4', label: 'Core Services'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '© 2025 Friend n Friends International. All rights reserved.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HomeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color.withValues(alpha: 0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientBadge extends StatelessWidget {
  final String name;
  const _ClientBadge(this.name);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF5A623),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: Colors.white.withValues(alpha: 0.15),
    );
  }
}
