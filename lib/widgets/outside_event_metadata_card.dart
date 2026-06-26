import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/manual_plan_item.dart';
import '../services/browser_open_url.dart';
import '../theme/app_colors.dart';

/// Compact, read-only summary of an outside event's sourced metadata,
/// shown wherever a [ManualPlanItem.isOutsideEvent] item appears (Plan day
/// sheet, Today). Shows whatever the source actually provided - confidence,
/// uncertain fields, and source/ticket links are all omitted rather than
/// faked when the source didn't supply them.
class OutsideEventMetadataCard extends StatelessWidget {
  const OutsideEventMetadataCard({super.key, required this.item});

  final ManualPlanItem item;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (item.outsideEventVenueName?.trim().isNotEmpty == true)
        item.outsideEventVenueName!.trim(),
      if (item.outsideEventAddress?.trim().isNotEmpty == true)
        item.outsideEventAddress!.trim(),
      if (item.outsideEventPriceLabel?.trim().isNotEmpty == true)
        item.outsideEventPriceLabel!.trim(),
    ];
    final sourceUrl = item.outsideEventSourceUrl?.trim();
    final ticketUrl = item.outsideEventTicketUrl?.trim();
    final hasSourceLink = sourceUrl?.isNotEmpty == true;
    final hasTicketLink =
        ticketUrl?.isNotEmpty == true && ticketUrl != sourceUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF6F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.outsideEventSourceName ?? 'Outside event',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentSage,
                  ),
                ),
              ),
              if (item.outsideEventConfidence != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${(item.outsideEventConfidence! * 100).round()}% confidence',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ],
            ],
          ),
          if (item.outsideEventSummary?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              item.outsideEventSummary!.trim(),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: textMuted,
                height: 1.35,
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              details.join(' / '),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textMuted,
              ),
            ),
          ],
          if (item.outsideEventTags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.outsideEventTags.take(5).map((tag) {
                return Text(
                  '#$tag',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                );
              }).toList(),
            ),
          ],
          if (item.outsideEventUncertainFields.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Uncertain: ${item.outsideEventUncertainFields.join(', ')}',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: textMuted,
                height: 1.3,
              ),
            ),
          ],
          if (hasSourceLink || hasTicketLink) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (hasSourceLink)
                  _MetadataLink(label: 'Details', url: sourceUrl!),
                if (hasTicketLink)
                  _MetadataLink(label: 'Tickets', url: ticketUrl!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetadataLink extends StatelessWidget {
  const _MetadataLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => triggerBrowserOpenUrl(url),
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: primaryTerracotta,
          decoration: TextDecoration.underline,
          decorationColor: primaryTerracotta,
        ),
      ),
    );
  }
}
