// The transport for this build.
//
// A target with dart:io opens a socket. A browser opens a WebSocket to the
// bridge. The call site is the same, which is what lets the protocol code
// stay one copy. The socket implementation is the default for the same reason
// as in io_types.dart: the analyzer does not treat dart.library.io as set.
export 'connector_io.dart'
    if (dart.library.html) 'connector_web.dart'
    if (dart.library.js_interop) 'connector_web.dart';
