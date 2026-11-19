import 'dart:io' hide SecurityContext, X509Certificate;
import 'dart:typed_data';

import '../mysql_client_error.dart';
import 'bridge_client.dart';
import 'byte_channel.dart';
import 'io_types.dart';

/// Open the connection the native driver uses.
///
/// With no [bridgeUrl] this is a TCP socket to [host] and [port], or a unix
/// socket when [isUnixSocket] is set: the same connection the driver has
/// always opened. With a [bridgeUrl] the bytes go over that WebSocket
/// instead, which is how tests and a non-browser client can talk to the same
/// bridge a page uses.
Future<ByteChannel> openByteChannel({
  required String host,
  required int port,
  required Duration timeout,
  required bool isUnixSocket,
  String? bridgeUrl,
  String? bridgeToken,
}) async {
  final bridge = bridgeUrl;
  if (bridge != null && bridge.isNotEmpty) {
    final token = bridgeToken;
    if (token == null || token.isEmpty) {
      throw MySqlClientError(
        'bridgeToken is required whenever bridgeUrl is '
        'set.',
      );
    }
    final ws = await WebSocket.connect(bridge).timeout(timeout);
    try {
      return await openBridgeChannel(
        frames: ws,
        sendText: ws.add,
        sendBytes: ws.add,
        close: () {
          ws.close();
        },
        done: ws.done.then((_) {}),
        token: token,
        timeout: timeout,
      );
    } catch (_) {
      await ws.close();
      rethrow;
    }
  }

  final Socket socket;
  if (isUnixSocket) {
    socket = await Socket.connect(
      InternetAddress(host, type: InternetAddressType.unix),
      port,
      timeout: timeout,
    );
  } else {
    socket = await Socket.connect(host, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
  }
  return _IoByteChannel(socket);
}

/// A [ByteChannel] over a `dart:io` socket, including one upgraded to TLS.
class _IoByteChannel implements ByteChannel {
  Socket _socket;

  _IoByteChannel(this._socket);

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  void add(List<int> data) {
    _socket.add(data);
  }

  @override
  Future<void> flush() => _socket.flush();

  @override
  Future<void> get done => _socket.done.then((_) {});

  @override
  void destroy() {
    _socket.destroy();
  }

  @override
  Future<void> startTls({
    String? host,
    SecurityContext? context,
    bool Function(X509Certificate certificate)? onBadCertificate,
  }) async {
    _socket = await SecureSocket.secure(
      _socket,
      host: host,
      context: context,
      onBadCertificate: onBadCertificate,
    );
  }
}
