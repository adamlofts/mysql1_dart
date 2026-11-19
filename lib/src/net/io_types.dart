// Socket and TLS types.
//
// The VM, Flutter mobile and the desktop take the real `dart:io` types. A
// browser, where `dart:html` or `dart:js_interop` exists, takes the stand-ins:
// the names match so the public API compiles, and nothing there can open a
// socket. The `dart:io` branch is the default rather than a condition,
// because the analyzer treats `dart.library.io` as unavailable even on the
// VM, and a condition on it would hand the VM the browser stand-ins.
export 'io_types_io.dart'
    if (dart.library.html) 'io_types_stub.dart'
    if (dart.library.js_interop) 'io_types_stub.dart';
