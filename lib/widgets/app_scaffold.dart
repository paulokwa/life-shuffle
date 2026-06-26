import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body, this.bottomNav});

  final Widget body;
  final Widget? bottomNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: body,
      bottomNavigationBar: bottomNav,
    );
  }
}
