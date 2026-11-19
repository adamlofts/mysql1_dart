// dart:html is deprecated in favour of package:web, which needs a newer SDK
// than this package declares. The WebSocket API used here is unchanged.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

import '../mysql_client_error.dart';
import 'bridge_client.dart';
import 'byte_channel.dart';

/// Open the connection a browser can actually open.
///
/// There is no TCP socket here and this does not try to invent one. [host]
/// and [port] are not dialed: the bridge has its own database address, fixed
/// when it was started, and the page does not get to choose another one.
/// [bridgeUrl] is that bridge's WebSocket.
Future<ByteChannel> openByteChannel({
  required String host,
  required int port,
  required Duration timeout,
  required bool isUnixSocket,
  String? bridgeUrl,
  String? bridgeToken,
}) {
  if (isUnixSocket) {
    throw MySqlClientError('A unix socket cannot be opened from the browser.');
  }
  final url = bridgeUrl;
  final token = bridgeToken;
  if (url == null || url.isEmpty || token == null || token.isEmpty) {
    throw MySqlClientError(
      'The browser cannot open a TCP connection to '
      '$host:$port. Set ConnectionSettings.bridgeUrl and bridgeToken.',
    );
  }
  return _openWebSocket(url, token, timeout);
}

Future<ByteChannel> _openWebSocket(String url, String token, Duration timeout) {
  final WebSocket ws;
  try {
    ws = WebSocket(url);
  } catch (e) {
    throw MySqlClientError(
      'Could not open a WebSocket to the MySQL bridge '
      'at $url: $e',
    );
  }
  ws.binaryType = 'arraybuffer';

  final ready = Completer<ByteChannel>();
  var settled = false;

  void fail(Object error) {
    if (settled) {
      return;
    }
    settled = true;
    ws.close();
    if (!ready.isCompleted) {
      ready.completeError(error);
    }
  }

  Timer(timeout, () {
    fail(MySqlClientError('Timed out connecting to the MySQL bridge at $url'));
  });

  ws.onError.listen((_) {
    fail(
      MySqlClientError(
        'Could not open a WebSocket to the MySQL bridge at $url',
      ),
    );
  });

  ws.onOpen.listen((_) {
    if (settled) {
      return;
    }
    openBridgeChannel(
      frames: ws.onMessage.map(_frameData),
      sendText: ws.send,
      sendBytes: _sendBytes(ws),
      close: () {
        ws.close();
      },
      done: ws.onClose.first.then((_) {}),
      token: token,
      timeout: timeout,
    ).then(
      (channel) {
        if (settled) {
          channel.destroy();
          return;
        }
        settled = true;
        if (!ready.isCompleted) {
          ready.complete(channel);
        }
      },
      onError: (Object error) {
        fail(error);
      },
    );
  });

  return ready.future;
}

/// What a WebSocket message carries: a [String], or the bytes of a binary frame.
dynamic _frameData(MessageEvent event) {
  final data = event.data;
  if (data is ByteBuffer) {
    return Uint8List.view(data);
  }
  return data;
}

void Function(List<int>) _sendBytes(WebSocket ws) {
  return (List<int> bytes) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    ws.send(data);
  };
}
