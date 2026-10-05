library mysql1.packet_stream;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// The most a single packet on the wire can carry. A longer payload is split
/// into packets of exactly this size followed by a shorter one - an empty one,
/// if the payload is an exact multiple.
const int maxPacketPayload = 0xffffff;

/// One message of the MySQL protocol, as the layers above the wire see it:
/// whole, however many packets it took to send.
class Packet {
  /// The sequence id of the last packet on the wire which carried it. A reply
  /// is numbered one after the packet it answers.
  final int sequenceId;

  /// The payload, without the header. This may be a view of the bytes the
  /// socket delivered rather than a copy.
  final Uint8List payload;

  Packet(this.sequenceId, this.payload);
}

/// Turns the bytes a socket delivers into the packets they carry.
///
/// One event comes out for each event which goes in and completes at least
/// one packet, holding all the packets it completed. A result set is a packet
/// per row and a socket read holds many of them, so this is what keeps the
/// cost of the stream to one event per read rather than one per row.
class PacketFramer extends StreamTransformerBase<Uint8List, List<Packet>> {
  const PacketFramer();

  @override
  Stream<List<Packet>> bind(Stream<Uint8List> stream) {
    final splitter = _PacketSplitter();
    return stream.transform(StreamTransformer.fromHandlers(
        handleData: (Uint8List chunk, EventSink<List<Packet>> sink) {
      final packets = splitter.add(chunk);
      if (packets.isNotEmpty) {
        sink.add(packets);
      }
    }));
  }
}

class _PacketSplitter {
  static const int _headerSize = 4;

  /// Bytes which have arrived but do not yet make up what is being waited for.
  final BytesBuilder _pending = BytesBuilder(copy: false);

  /// How many bytes [_pending] has to hold before any of it can be used: a
  /// header, or a header and the payload it describes.
  int _needed = _headerSize;

  /// The parts so far of a payload which was split because of its length.
  BytesBuilder? _parts;

  List<Packet> add(Uint8List chunk) {
    Uint8List data;
    if (_pending.isEmpty) {
      data = chunk;
    } else {
      _pending.add(chunk);
      if (_pending.length < _needed) {
        return const [];
      }
      data = _pending.takeBytes();
    }

    final packets = <Packet>[];
    var offset = 0;
    while (true) {
      final remaining = data.length - offset;
      if (remaining < _headerSize) {
        _needed = _headerSize;
        break;
      }
      final length =
          data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16);
      if (remaining < _headerSize + length) {
        _needed = _headerSize + length;
        break;
      }
      final sequenceId = data[offset + 3];
      final start = offset + _headerSize;
      final payload = Uint8List.sublistView(data, start, start + length);
      offset = start + length;

      final parts = _parts;
      if (length == maxPacketPayload) {
        (_parts ??= BytesBuilder(copy: false)).add(payload);
      } else if (parts != null) {
        parts.add(payload);
        packets.add(Packet(sequenceId, parts.takeBytes()));
        _parts = null;
      } else {
        packets.add(Packet(sequenceId, payload));
      }
    }

    if (offset < data.length) {
      _pending.add(Uint8List.sublistView(data, offset));
    }
    return packets;
  }
}

/// Hands out the packets of a stream one at a time, to code which asks for
/// them.
///
/// The protocol is request and response, and a response is as many packets as
/// it takes. Reading one is a loop which asks for the next packet until it has
/// seen the last, and this is what it asks.
class PacketReader {
  late final StreamSubscription<List<Packet>> _subscription;

  List<Packet> _batch = const [];
  int _next = 0;

  /// Whoever is waiting for a batch to arrive.
  Completer<void>? _waiting;

  Object? _error;
  StackTrace? _errorStackTrace;
  bool _done = false;

  /// The sequence id of the packet most recently handed out.
  int lastSequenceId = -1;

  PacketReader(Stream<List<Packet>> packets) {
    _subscription = packets.listen(_onBatch, onError: _onError, onDone: () {
      _done = true;
      _wake();
    });
  }

  /// Whether the stream has ended, by closing or with an error.
  bool get isClosed => _done || _error != null;

  void _onBatch(List<Packet> batch) {
    if (_next < _batch.length) {
      // Only when a pause has yet to take effect.
      _batch = [..._batch.sublist(_next), ...batch];
    } else {
      _batch = batch;
    }
    _next = 0;
    if (_waiting == null) {
      // Nobody is reading. Leave the rest in the socket, which is what tells
      // the server to slow down.
      _subscription.pause();
    }
    _wake();
  }

  void _onError(Object error, StackTrace stackTrace) => fail(error, stackTrace);

  /// End the reading with [error]. The packets which have already arrived can
  /// still be read, and after them [next] throws it.
  void fail(Object error, StackTrace stackTrace) {
    _error ??= error;
    _errorStackTrace ??= stackTrace;
    _wake();
  }

  void _wake() {
    final waiting = _waiting;
    _waiting = null;
    waiting?.complete();
  }

  /// The next packet if it has already arrived, and null if not.
  ///
  /// `poll() ?? await next()` reads a packet without going round the event
  /// loop for one which is already here.
  Packet? poll() {
    if (_next < _batch.length) {
      final packet = _batch[_next++];
      lastSequenceId = packet.sequenceId;
      return packet;
    }
    return null;
  }

  /// The next packet, waiting for it to arrive if it has to.
  ///
  /// Throws the error the stream ended with, or a [SocketException] if it was
  /// closed.
  Future<Packet> next() async {
    while (true) {
      final packet = poll();
      if (packet != null) {
        return packet;
      }
      final error = _error;
      if (error != null) {
        Error.throwWithStackTrace(
            error, _errorStackTrace ?? StackTrace.current);
      }
      if (_done) {
        throw const SocketException.closed();
      }
      if (_waiting != null) {
        throw StateError('A packet is already being waited for');
      }
      final waiting = _waiting = Completer<void>();
      if (_subscription.isPaused) {
        _subscription.resume();
      }
      await waiting.future;
    }
  }

  /// Stop listening without closing the source, so that something else can
  /// take it over. Used to start TLS on a connection which has begun in the
  /// clear.
  void pause() {
    if (!_subscription.isPaused) {
      _subscription.pause();
    }
  }

  /// Stop reading. Whoever is waiting for a packet gets a [SocketException].
  void close() {
    _done = true;
    _subscription.cancel();
    _wake();
  }
}

/// Frames [payload] for the wire: a header before it, and before each further
/// part of it if it is too long for one packet.
///
/// [sequenceId] numbers the first packet, and the id of the last one is
/// returned along with the bytes.
(Uint8List, int) encodePackets(Uint8List payload, int sequenceId) {
  final packetCount = payload.length ~/ maxPacketPayload + 1;
  final out = Uint8List(payload.length + packetCount * 4);
  var read = 0;
  var write = 0;
  var id = sequenceId;
  for (var i = 0; i < packetCount; i++) {
    final remaining = payload.length - read;
    final length = remaining < maxPacketPayload ? remaining : maxPacketPayload;
    id = (sequenceId + i) & 0xff;
    out[write] = length & 0xff;
    out[write + 1] = (length >> 8) & 0xff;
    out[write + 2] = (length >> 16) & 0xff;
    out[write + 3] = id;
    write += 4;
    out.setRange(write, write + length, payload, read);
    write += length;
    read += length;
  }
  return (out, id);
}
