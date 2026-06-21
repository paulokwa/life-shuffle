// Triggers the platform print dialog when running on web; returns `false`
// everywhere else so callers can show their own print guidance instead.
export 'browser_print_stub.dart'
    if (dart.library.html) 'browser_print_web.dart';
