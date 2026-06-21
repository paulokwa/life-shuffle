enum SyncMessageSeverity { info, warning, error }

/// Small plain-language message describing a shared-calendar sync problem
/// or notice (e.g. a failed save/load, or a newer remote version that was
/// just applied). Built from safe [AppState] sync status fields; never
/// carries raw Firebase exception text.
class SyncMessage {
  const SyncMessage({
    required this.severity,
    required this.title,
    required this.body,
    this.actionLabel,
  });

  final SyncMessageSeverity severity;
  final String title;
  final String body;
  final String? actionLabel;
}
