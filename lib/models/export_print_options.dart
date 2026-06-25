/// User-controlled visibility for optional fields in the weekly text export
/// and print preview. Activity title and date/day have no toggle and are
/// always shown. All fields default to `true` so existing copy/print output
/// is unchanged until a user turns something off.
class ExportPrintOptions {
  const ExportPrintOptions({
    this.showTime = true,
    this.showDuration = true,
    this.showCategory = true,
    this.showCheckInStatus = true,
    this.showLockedStatus = true,
    this.showEnabledDimensions = true,
    this.showOutsideEventDetails = true,
  });

  final bool showTime;
  final bool showDuration;
  final bool showCategory;
  final bool showCheckInStatus;
  final bool showLockedStatus;
  final bool showEnabledDimensions;

  /// Whether outside-event items also export their venue/price/source/
  /// ticket metadata, not just the title and time every plan item gets.
  final bool showOutsideEventDetails;

  ExportPrintOptions copyWith({
    bool? showTime,
    bool? showDuration,
    bool? showCategory,
    bool? showCheckInStatus,
    bool? showLockedStatus,
    bool? showEnabledDimensions,
    bool? showOutsideEventDetails,
  }) {
    return ExportPrintOptions(
      showTime: showTime ?? this.showTime,
      showDuration: showDuration ?? this.showDuration,
      showCategory: showCategory ?? this.showCategory,
      showCheckInStatus: showCheckInStatus ?? this.showCheckInStatus,
      showLockedStatus: showLockedStatus ?? this.showLockedStatus,
      showEnabledDimensions:
          showEnabledDimensions ?? this.showEnabledDimensions,
      showOutsideEventDetails:
          showOutsideEventDetails ?? this.showOutsideEventDetails,
    );
  }
}
