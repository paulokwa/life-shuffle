import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/ls_card.dart';

class DisplayNameScreen extends StatefulWidget {
  const DisplayNameScreen({
    super.key,
    required this.initialName,
    required this.onConfirm,
  });

  final String initialName;
  final bool Function(String displayName) onConfirm;

  @override
  State<DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends State<DisplayNameScreen> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final saved = widget.onConfirm(_controller.text);
    setState(() {
      _errorText = saved ? null : 'Enter a display name to continue.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: warmBeige,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.shuffle_rounded,
                          size: 18,
                          color: primaryTerracotta,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Life Shuffle',
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Confirm your name',
                    style: GoogleFonts.lora(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is the name Life Shuffle will show in your account settings.',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Display name',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.words,
                          onSubmitted: (_) => _confirm(),
                          decoration: InputDecoration(
                            hintText: 'Your name',
                            errorText: _errorText,
                            filled: true,
                            fillColor: backgroundCream,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: borderWarm),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: borderWarm),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: primaryTerracotta,
                              ),
                            ),
                          ),
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _confirm,
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: primaryTerracotta,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Continue',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
