library mysql1.protocol_connection;

import 'dart:async';
import 'dart:io';

import 'package:pool/pool.dart';

import 'buffer.dart';
import 'mysql_client_error.dart';
import 'mysql_exception.dart';
import 'packet_stream.dart';

/// The connection to the server, as something which packets are sent to and
/// read from.
///
/// MySQL is a request and response protocol with one exchange on the wire at
/// a time: a request goes out, and its response is every packet up to the one
/// which ends it. [exchange] is that unit. The code inside one sends with
/// [send] and reads with [poll] and [next], as ordinary sequential code, and
/// nothing else can use the connection until it is done.
class ProtocolConnection {
  Socket _socket;
  late PacketReader _reader;
  final int _maxPacketSize;

  /// One exchange at a time. The others wait here.
  final Pool _lock = Pool(1);

  /// The sequence id of the last packet sent or read in this exchange. Each
  /// packet is numbered one after the last, whichever side sent it, and the
  /// count starts again with each request.
  int _sequenceId = -1;

  /// Whether the exchange in progress has put anything on the wire.
  bool _sent = false;

  bool _closed = false;

  ProtocolConnection(this._socket, this._maxPacketSize) {
    _listen();
  }

  static Future<ProtocolConnection> connect(
      String host, int port, Duration timeout, int maxPacketSize,
      {bool isUnixSocket = false}) async {
    final Socket socket;
    if (isUnixSocket) {
      socket = await Socket.connect(
          InternetAddress(host, type: InternetAddressType.unix), port,
          timeout: timeout);
    } else {
      socket = await Socket.connect(host, port, timeout: timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
    }
    return ProtocolConnection(socket, maxPacketSize);
  }

  void _listen() {
    final reader =
        _reader = PacketReader(_socket.transform(const PacketFramer()));
    // A write which fails is reported on the socket's done future and nowhere
    // else. Whoever sent it is by then waiting for the reply, so that is who
    // is told.
    _socket.done.catchError(reader.fail);
  }

  bool get isClosed => _closed;

  /// Run [body] as the only thing using the connection, giving it [timeout]
  /// to finish.
  ///
  /// If [body] fails with a [MySqlException], the server has ended the
  /// response with an error and the connection is ready for the next request.
  /// If it fails in any other way after sending something - a timeout, a
  /// socket error, a packet which makes no sense - there is no telling where
  /// in the response the wire is, so the connection is closed.
  Future<T> exchange<T>(Future<T> Function() body, Duration timeout) {
    return _lock.withResource(() async {
      if (_closed) {
        throw StateError('Cannot write to socket, it is closed');
      }
      _sequenceId = -1;
      _sent = false;
      try {
        return await body().timeout(timeout);
      } on MySqlException {
        rethrow;
      } catch (_) {
        if (_sent) {
          close();
        }
        rethrow;
      }
    });
  }

  /// Send [payload] as the next packet of the exchange.
  void send(Buffer payload) {
    if (_closed) {
      throw StateError('Cannot write to socket, it is closed');
    }
    if (payload.length > _maxPacketSize) {
      throw MySqlClientError(
          'Buffer length (${payload.length}) bigger than maxPacketSize ($_maxPacketSize)');
    }
    final (bytes, sequenceId) = encodePackets(payload.list, _sequenceId + 1);
    _sequenceId = sequenceId;
    _sent = true;
    _socket.add(bytes);
  }

  /// Wait until everything sent has been handed to the operating system.
  Future<void> flush() => _socket.flush();

  /// The next packet of the response if it has already arrived, and null if
  /// not. `poll() ?? await next()` avoids a trip round the event loop for a
  /// packet which is already here.
  Packet? poll() {
    final packet = _reader.poll();
    if (packet != null) {
      _sequenceId = packet.sequenceId;
    }
    return packet;
  }

  /// The next packet of the response.
  Future<Packet> next() async {
    final packet = await _reader.next();
    _sequenceId = packet.sequenceId;
    return packet;
  }

  /// Switch the connection to TLS. The server's certificate is not checked.
  Future<void> startTls() async {
    // The socket's subscription stops getting events once TLS takes over, and
    // pausing it rather than cancelling is what leaves the socket open.
    _reader.pause();
    _socket = await SecureSocket.secure(_socket, onBadCertificate: (_) => true);
    _listen();
  }

  /// Close the connection now. Whatever is waiting for a packet fails with a
  /// [SocketException].
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _reader.close();
    _socket.destroy();
  }
}
