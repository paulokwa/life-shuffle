/// Non-web platforms (mobile, `flutter test`'s VM target) have no browser
/// tab to open; callers fall back to copying the link instead.
bool triggerBrowserOpenUrl(String url) => false;
