import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mysql1/src/packet_stream.dart';
import 'package:mysql1/src/protocol_connection.dart';

/// The server's end of a connection over loopback, for tests which need to
/// say exactly which packets come back.
class FakeServer {
  final ServerSocket _listener;
  final ProtocolConnection client;
  Socket _socket;
  PacketReader _requests;

  FakeServer._(this._listener, this.client, this._socket)
      : _requests = PacketReader(_socket.transform(const PacketFramer()));

  static Future<FakeServer> start(
      {int maxPacketSize = 16 * 1024 * 1024}) async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = listener.first;
    final client = await ProtocolConnection.connect(
        '127.0.0.1', listener.port, const Duration(seconds: 5), maxPacketSize);
    return FakeServer._(listener, client, await accepted);
  }

  /// The next packet the client sent.
  Future<Packet> nextRequest() => _requests.next();

  /// Send [payloads] as consecutive packets, numbered from [sequenceId].
  void send(List<List<int>> payloads, {int sequenceId = 1}) {
    for (final payload in payloads) {
      final (bytes, _) =
          encodePackets(Uint8List.fromList(payload), sequenceId++);
      _socket.add(bytes);
    }
  }

  /// Switch the server's end to TLS, presenting the certificate in
  /// [context]. Completes when the client has done the same, and fails if
  /// the client would not.
  Future<void> startTls(SecurityContext context) async {
    _requests.pause();
    _socket = await SecureSocket.secureServer(_socket, context);
    _requests = PacketReader(_socket.transform(const PacketFramer()));
  }

  /// Drop the connection from the server's end.
  void hangUp() => _socket.destroy();

  Future<void> close() async {
    client.close();
    _socket.destroy();
    await _listener.close();
  }
}
