import 'dart:html' as html;

bool triggerBrowserOpenUrl(String url) {
  html.window.open(url, '_blank');
  return true;
}
