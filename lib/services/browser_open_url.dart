// Opens a URL in a new browser tab on web; returns `false` everywhere else
// so callers can fall back to copying the link instead.
export 'browser_open_url_stub.dart'
    if (dart.library.html) 'browser_open_url_web.dart';
