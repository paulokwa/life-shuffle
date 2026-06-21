/// Non-web platforms (mobile, `flutter test`'s VM target) have no browser
/// print dialog to trigger; callers fall back to their own guidance text.
bool triggerBrowserPrint() => false;
