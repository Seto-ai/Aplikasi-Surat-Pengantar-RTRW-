import 'package:flutter/material.dart';

// Centralized theme values and small reusable widgets for consistent UI
const double kPagePadding = 16.0;
final Color kPrimaryGreen = Color(0xFF27AE60);
final Color kPrimaryLightGreen = Color(0xFFF3FBF5);

// Modern theme dengan dominan putih dan aksen hijau
ThemeData getAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: kPrimaryGreen,
    scaffoldBackgroundColor: Colors.white,
    
    // AppBar styling
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0.5,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.grey.shade800),
      titleTextStyle: TextStyle(
        color: Colors.grey.shade800,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Button styling
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryGreen,
      ),
    ),

    // Input field styling
    inputDecorationTheme: InputDecorationTheme(
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
        borderSide: BorderSide(color: kPrimaryGreen, width: 2),
      ),
      prefixIconColor: kPrimaryGreen,
      labelStyle: TextStyle(color: Colors.grey.shade600),
    ),

    // Card styling
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
    ),

    // Color scheme
    colorScheme: ColorScheme.light(
      primary: kPrimaryGreen,
      secondary: Color(0xFF229954),
      surface: Colors.white,
      error: Colors.red.shade600,
    ),
  );
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SectionCard({Key? key, required this.child, this.padding = const EdgeInsets.all(16)}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(padding: padding, child: child),
    );
  }
}

Widget verticalSpace([double h = 12]) => SizedBox(height: h);
