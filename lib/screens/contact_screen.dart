import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Real contact information from fnfinternational.odoo.com
  static const String _companyEmail = 'Friendnfriendsinternational@gmail.com';
  static const String _whatsappNumber = '923115177747';
  static const String _whatsappDisplayNumber = '+92 311 5177747';

  Future<void> _launchWhatsApp() async {
    final message = Uri.encodeComponent(
        'Hello Friend n Friends International, I am interested in learning more about your services, including government projects, construction, interior design, and general supplies. Please share more details.');
    final url = Uri.parse('https://wa.me/$_whatsappNumber?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('WhatsApp could not be opened. Try again.');
    }
  }

  Future<void> _launchEmail() async {
    final subject =
        Uri.encodeComponent('Inquiry – Friend n Friends International');
    final body = Uri.encodeComponent(
        'Dear Friend n Friends International Team,\n\nI hope this message finds you well.\n\nI would like to learn more about your services — particularly your work in government contracting, construction, interior design, and general supply solutions.\n\nPlease share more details regarding your offerings, project timelines, and partnership opportunities.\n\nThank you,\n[Your Name]\n[Your Company / Organization]\n[Your Contact Number]');
    final url = Uri.parse('mailto:$_companyEmail?subject=$subject&body=$body');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showSnack(
          'Cannot open email app. Please email us directly at $_companyEmail');
    }
  }

  Future<void> _launchWebsite() async {
    final url = Uri.parse('https://fnfinternational.odoo.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open website.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _sendViaWhatsApp();
    }
  }

  Future<void> _sendViaWhatsApp() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    final whatsappMsg = Uri.encodeComponent(
      '📋 *NEW INQUIRY — Friend n Friends International*\n'
      '━━━━━━━━━━━━━━━━━━━━━━\n'
      '👤 *Name:* $name\n'
      '📱 *Phone:* $phone\n'
      '${email.isNotEmpty ? '📧 *Email:* $email\n' : ''}'
      '🕐 *Date:* $dateStr\n'
      '━━━━━━━━━━━━━━━━━━━━━━\n'
      '💬 *Message:*\n$message\n'
      '━━━━━━━━━━━━━━━━━━━━━━\n'
      '_Sent via FnF International App_',
    );

    final url = Uri.parse('https://wa.me/$_whatsappNumber?text=$whatsappMsg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) {
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Message sent via WhatsApp!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      _showSnack('Could not open WhatsApp. Please contact us directly.');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              color: const Color(0xFF1A3A5C),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get In Touch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'We\'re here to help with your construction and supply needs.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Contact Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _QuickContactButton(
                          icon: Icons.chat,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          onTap: _launchWhatsApp,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickContactButton(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          color: const Color(0xFFEA4335),
                          onTap: _launchEmail,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickContactButton(
                          icon: Icons.language,
                          label: 'Website',
                          color: const Color(0xFF1A3A5C),
                          onTap: _launchWebsite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Contact Info Card
                  _InfoCard(
                    onWhatsApp: _launchWhatsApp,
                    onEmail: _launchEmail,
                    onWebsite: _launchWebsite,
                  ),
                  const SizedBox(height: 20),
                  // Message Form
                  Container(
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Send Us a Message'),
                          const SizedBox(height: 16),
                          _FormField(
                            controller: _nameController,
                            label: 'Full Name',
                            hint: 'e.g. Ahmed Khan',
                            icon: Icons.person_outline,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _FormField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: '+92 311 5177747',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-\s]')),
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Phone number is required';
                              }
                              if (v.trim().length < 10) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _FormField(
                            controller: _emailController,
                            label: 'Email (Optional)',
                            hint: 'yourname@email.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v != null && v.isNotEmpty) {
                                if (!v.contains('@') || !v.contains('.')) {
                                  return 'Enter a valid email address';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Message',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A3A5C),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _messageController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText:
                                  'Tell us about your project or supply requirements...',
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF1A3A5C), width: 2),
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter a message';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _submitForm,
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Send via WhatsApp'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A3A5C),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // WhatsApp Big Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _launchWhatsApp,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                color: Colors.white, size: 26),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chat on WhatsApp',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _whatsappDisplayNumber,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Spacer(),
                            Icon(Icons.arrow_forward_ios,
                                color: Colors.white70, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;
  final VoidCallback onWebsite;

  const _InfoCard({
    required this.onWhatsApp,
    required this.onEmail,
    required this.onWebsite,
  });

  @override
  Widget build(BuildContext context) {
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
          const _SectionTitle('Contact Information'),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onWhatsApp,
            child: const _ContactInfoRow(
              icon: Icons.chat,
              iconColor: Color(0xFF25D366),
              label: 'WhatsApp',
              value: '+92 311 5177747',
              isLink: true,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onEmail,
            child: const _ContactInfoRow(
              icon: Icons.email_outlined,
              iconColor: Color(0xFFEA4335),
              label: 'Email',
              value: 'Friendnfriendsinternational@gmail.com',
              isLink: true,
            ),
          ),
          const SizedBox(height: 12),
          const _ContactInfoRow(
            icon: Icons.location_on_outlined,
            iconColor: Color(0xFFF5A623),
            label: 'Branch Office',
            value:
                'House # 310, Lower Khalilzai,\nGarhi Pana Chowk, Nawan Shehr',
            isLink: false,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onWebsite,
            child: const _ContactInfoRow(
              icon: Icons.language,
              iconColor: Color(0xFF1A3A5C),
              label: 'Website',
              value: 'fnfinternational.odoo.com',
              isLink: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isLink;

  const _ContactInfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isLink,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isLink
                      ? const Color(0xFF1A3A5C)
                      : const Color(0xFF333333),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: isLink ? TextDecoration.underline : null,
                  decorationColor: isLink ? const Color(0xFF1A3A5C) : null,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A3A5C),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(icon, color: const Color(0xFF1A3A5C), size: 20),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
      ],
    );
  }
}
