import 'dart:typed_data';

import 'io_types.dart';

/// The bytes of one MySQL connection, whatever carries them.
///
/// On a server, a phone or a desktop this is a TCP socket, or a unix socket.
/// In a browser it is a WebSocket to the bridge, which holds the real socket.
/// The protocol above writes packets and reads packets and does not know
/// which of the two it has.
abstract class ByteChannel {
  /// Bytes as they arrive. Chunk boundaries are not packet boundaries.
  Stream<Uint8List> get stream;

  /// Queue [data] to be written. It is not on the wire until [flush].
  void add(List<int> data);

  /// Wait until everything passed to [add] has been handed on.
  Future<void> flush();

  /// Completes when the connection is finished, with an error if it failed.
  Future<void> get done;

  /// Drop the connection. Waiting for a packet then fails.
  void destroy();

  /// Replace the cleartext connection with TLS, as MySQL's upgrade does.
  ///
  /// Only a real socket can do this. A bridge connection throws, because the
  /// browser has no way to upgrade the bytes it is forwarding, and pretending
  /// otherwise would desynchronise the protocol.
  Future<void> startTls({
    String? host,
    SecurityContext? context,
    bool Function(X509Certificate certificate)? onBadCertificate,
  });
}
