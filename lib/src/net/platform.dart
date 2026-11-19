// Whether this build is running where a page runs, with no TCP sockets.
//
// A browser has dart:html or dart:js_interop. Everywhere else is native.
// Native is the default so the analyzer, which does not set dart.library.io,
// still treats tests and the VM as native.
export 'platform_native.dart'
    if (dart.library.html) 'platform_browser.dart'
    if (dart.library.js_interop) 'platform_browser.dart';
