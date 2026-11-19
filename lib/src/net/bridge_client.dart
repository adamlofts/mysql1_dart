import 'dart:async';
import 'dart:typed_data';

import '../bridge/bridge_protocol.dart';
import '../mysql_client_error.dart';
import 'byte_channel.dart';
import 'io_types.dart';
import 'web_guard.dart';

/// Complete the bridge handshake on [frames] and return the byte channel.
///
/// [frames] yields a [String] for a text frame and a [List<int>] for a binary
/// one. The auth frame is sent immediately, so [frames] must already be
/// listening by the time this awaits: the function subscribes before it
/// sends. Binary frames which arrive before [bridgeAuthOk] are kept. That is
/// the MySQL greeting, which the server writes as soon as the bridge connects
/// and which can overtake the `ok` on the way back to the page.
Future<ByteChannel> openBridgeChannel({
  required Stream<dynamic> frames,
  required void Function(String text) sendText,
  required void Function(List<int> bytes) sendBytes,
  required void Function() close,
  required Future<void> done,
  required String token,
  required Duration timeout,
}) async {
  final incoming = StreamController<Uint8List>();
  final ready = Completer<void>();
  final pending = <Uint8List>[];
  var authed = false;

  void fail(Object error, StackTrace stackTrace) {
    if (!ready.isCompleted) {
      ready.completeError(error, stackTrace);
    }
    if (!incoming.isClosed) {
      incoming.addError(error, stackTrace);
    }
  }

  final subscription = frames.listen(
    (frame) {
      if (!authed) {
        if (frame is String) {
          if (frame == bridgeAuthOk) {
            authed = true;
            for (final chunk in pending) {
              incoming.add(chunk);
            }
            if (!ready.isCompleted) {
              ready.complete();
            }
          } else {
            fail(
              MySqlClientError('The MySQL bridge refused the connection'),
              StackTrace.current,
            );
            close();
          }
          return;
        }
        if (frame is List<int>) {
          pending.add(frame is Uint8List ? frame : Uint8List.fromList(frame));
          return;
        }
        return;
      }
      if (frame is List<int>) {
        incoming.add(frame is Uint8List ? frame : Uint8List.fromList(frame));
        return;
      }
      fail(
        MySqlClientError(
          'The MySQL bridge sent a text frame after the '
          'connection was open',
        ),
        StackTrace.current,
      );
    },
    onError: fail,
    onDone: () {
      if (!ready.isCompleted) {
        fail(
          MySqlClientError(
            'The MySQL bridge closed before the connection was ready',
          ),
          StackTrace.current,
        );
      }
      if (!incoming.isClosed) {
        incoming.close();
      }
    },
  );

  sendText('$bridgeAuthPrefix$token');

  try {
    await ready.future.timeout(timeout);
  } catch (e) {
    await subscription.cancel();
    close();
    rethrow;
  }

  return _BridgeByteChannel(
    stream: incoming.stream,
    sendBytes: sendBytes,
    done: done,
    close: () {
      subscription.cancel();
      close();
      if (!incoming.isClosed) {
        incoming.close();
      }
    },
  );
}

class _BridgeByteChannel implements ByteChannel {
  @override
  final Stream<Uint8List> stream;

  final void Function(List<int> bytes) _sendBytes;
  final void Function() _close;

  @override
  final Future<void> done;

  _BridgeByteChannel({
    required this.stream,
    required void Function(List<int> bytes) sendBytes,
    required void Function() close,
    required this.done,
  }) : _sendBytes = sendBytes,
       _close = close;

  @override
  void add(List<int> data) {
    _sendBytes(data);
  }

  /// The WebSocket has already accepted the bytes. Yielding lets it write
  /// them before the caller waits for the reply.
  @override
  Future<void> flush() => Future<void>.value();

  @override
  void destroy() {
    _close();
  }

  @override
  Future<void> startTls({
    String? host,
    SecurityContext? context,
    bool Function(X509Certificate certificate)? onBadCertificate,
  }) {
    rejectBridgeTls();
  }
}
