import 'package:flutter/material.dart';

// Centralized theme values and small reusable widgets for consistent UI
const double kPagePadding = 16.0;
final Color kPrimaryGreen = Colors.green.shade700;
final Color kPrimaryLightGreen = Color(0xFFF3FBF5);

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
