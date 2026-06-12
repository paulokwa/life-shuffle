import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LsCard extends StatelessWidget {
  const LsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20.0,
    this.color = surfaceWhite,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderWarm, width: 1),
      ),
      child: child,
    );
  }
}
