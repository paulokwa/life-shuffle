import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/mock_data.dart';

class CheckInCircle extends StatelessWidget {
  const CheckInCircle({
    super.key,
    required this.status,
    this.onTap,
    this.size = 32.0,
  });

  final CheckStatus status;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: _decoration(),
        alignment: Alignment.center,
        child: _child(),
      ),
    );
  }

  BoxDecoration _decoration() {
    switch (status) {
      case CheckStatus.none:
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderWarm, width: 2),
        );
      case CheckStatus.done:
        return const BoxDecoration(
          shape: BoxShape.circle,
          color: accentSage,
        );
      case CheckStatus.partly:
        return BoxDecoration(
          shape: BoxShape.circle,
          color: sand.withOpacity(0.20),
          border: Border.all(color: sand, width: 2),
        );
      case CheckStatus.skipped:
        return BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderWarm, width: 2),
        );
    }
  }

  Widget? _child() {
    switch (status) {
      case CheckStatus.none:
        return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: borderWarm,
          ),
        );
      case CheckStatus.done:
        return const Icon(Icons.check_rounded, size: 14, color: surfaceWhite);
      case CheckStatus.partly:
        return const Text(
          '◐',
          style: TextStyle(
            fontSize: 12,
            color: sand,
            fontWeight: FontWeight.bold,
          ),
        );
      case CheckStatus.skipped:
        return const Text(
          '○',
          style: TextStyle(fontSize: 12, color: textMuted),
        );
    }
  }
}
