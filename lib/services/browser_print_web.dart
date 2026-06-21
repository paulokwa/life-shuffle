import 'dart:html' as html;

bool triggerBrowserPrint() {
  html.window.print();
  return true;
}
