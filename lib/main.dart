import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/quotation_screen.dart';
import 'screens/supply_screen.dart';

void main() {
  runApp(const FnFApp());
}

class FnFApp extends StatelessWidget {
  const FnFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Friend n Friends International',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3A5C),
          primary: const Color(0xFF1A3A5C),
          secondary: const Color(0xFFF5A623),
          surface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A3A5C),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A3A5C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
      routes: {
        '/quotation-preview': (_) => const QuotationScreen(),
        '/custom-quotation-preview':
            (_) => const QuotationScreen(startInCustomMode: true),
        '/supply-preview': (_) => const SupplyScreen(),
      },
      home: const HomeScreen(),
    );
  }
}
