library mysql1.packet_stream_test;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mysql1/src/packet_stream.dart';
import 'package:test/test.dart';

Uint8List _bytes(List<int> bytes) => Uint8List.fromList(bytes);

/// Frame [chunks] and return what came out, an entry for each event.
Future<List<List<List<int>>>> _frame(List<List<int>> chunks) async {
  final batches = await Stream.fromIterable(chunks.map(_bytes))
      .transform(const PacketFramer())
      .toList();
  return [
    for (final batch in batches) [for (final packet in batch) packet.payload]
  ];
}

void main() {
  group('framing', () {
    test('a packet', () async {
      expect(
          await _frame([
            [3, 0, 0, 0, 1, 2, 3]
          ]),
          equals([
            [
              [1, 2, 3]
            ]
          ]));
    });

    test('the packets which arrive together come out together', () async {
      expect(
          await _frame([
            [1, 0, 0, 0, 7, 2, 0, 0, 1, 8, 9],
            [1, 0, 0, 2, 6]
          ]),
          equals([
            [
              [7],
              [8, 9]
            ],
            [
              [6]
            ]
          ]));
    });

    test('a packet which arrives in pieces', () async {
      expect(
          await _frame([
            [3, 0],
            [0, 0, 1],
            [2],
            [3, 1, 0, 0, 1, 4]
          ]),
          equals([
            [
              [1, 2, 3],
              [4]
            ]
          ]));
    });

    test('nothing comes out until a packet is complete', () async {
      expect(
          await _frame([
            [3, 0, 0, 0, 1, 2]
          ]),
          isEmpty);
    });

    test('an empty packet', () async {
      expect(
          await _frame([
            [0, 0, 0, 0, 1, 0, 0, 1, 5]
          ]),
          equals([
            [
              <int>[],
              [5]
            ]
          ]));
    });

    test('carries the sequence id', () async {
      final batches = await Stream.value(_bytes([1, 0, 0, 42, 7]))
          .transform(const PacketFramer())
          .toList();
      expect(batches.single.single.sequenceId, equals(42));
    });

    // A payload too long for one packet is sent as packets of the largest
    // size and then a shorter one, which is what says it is over.
    test('a payload split across packets is joined', () async {
      final first = Uint8List(4 + maxPacketPayload)
        ..setAll(0, [0xff, 0xff, 0xff, 1]);
      first[4] = 11;
      final batches = await Stream.fromIterable([
        first,
        _bytes([2, 0, 0, 2, 12, 13])
      ]).transform(const PacketFramer()).toList();

      final packet = batches.single.single;
      expect(packet.payload.length, equals(maxPacketPayload + 2));
      expect(packet.payload.first, equals(11));
      expect(packet.payload.sublist(maxPacketPayload), equals([12, 13]));
      expect(packet.sequenceId, equals(2));
    });

    test('a payload which exactly fills a packet ends with an empty one',
        () async {
      final first = Uint8List(4 + maxPacketPayload)
        ..setAll(0, [0xff, 0xff, 0xff, 1]);
      final batches = await Stream.fromIterable([
        first,
        _bytes([0, 0, 0, 2, 1, 0, 0, 3, 9])
      ]).transform(const PacketFramer()).toList();

      final packets = batches.expand((batch) => batch).toList();
      expect(packets, hasLength(2));
      expect(packets[0].payload.length, equals(maxPacketPayload));
      expect(packets[1].payload, equals([9]));
    });
  });

  group('encoding', () {
    test('a payload gets a header', () {
      final (bytes, last) = encodePackets(_bytes([1, 2, 3]), 5);
      expect(bytes, equals([3, 0, 0, 5, 1, 2, 3]));
      expect(last, equals(5));
    });

    test('an empty payload', () {
      final (bytes, _) = encodePackets(Uint8List(0), 0);
      expect(bytes, equals([0, 0, 0, 0]));
    });

    test('the sequence id wraps', () {
      final (bytes, last) = encodePackets(_bytes([1]), 256);
      expect(bytes[3], equals(0));
      expect(last, equals(0));
    });

    test('a long payload is split', () {
      final length = 17 * 1024 * 1024;
      final (bytes, last) = encodePackets(Uint8List(length), 1);
      expect(bytes.length, equals(length + 8));
      expect(bytes.sublist(0, 4), equals([0xff, 0xff, 0xff, 1]));
      expect(bytes.sublist(4 + maxPacketPayload, 8 + maxPacketPayload),
          equals([1, 0, 16, 2]));
      expect(last, equals(2));
    });

    test('a payload which exactly fills a packet is ended by an empty one', () {
      final (bytes, last) = encodePackets(Uint8List(maxPacketPayload), 0);
      expect(bytes.length, equals(maxPacketPayload + 8));
      expect(bytes.sublist(bytes.length - 4), equals([0, 0, 0, 1]));
      expect(last, equals(1));
    });

    test('the bytes after the last whole packet can be taken back', () {
      final splitter = PacketSplitter();
      final packets = splitter.add(_bytes([1, 0, 0, 0, 7, 22, 3, 1]));
      expect(packets.single.payload, equals([7]));
      expect(splitter.takePending(), equals([22, 3, 1]));
      expect(splitter.takePending(), isEmpty);
      // Framing starts afresh at a header.
      expect(splitter.add(_bytes([1, 0, 0, 1, 8])).single.payload, equals([8]));
    });

    test('what is encoded can be framed', () async {
      final payload = Uint8List(maxPacketPayload * 2 + 5)..[0] = 3;
      final (bytes, _) = encodePackets(payload, 0);
      final batches =
          await Stream.value(bytes).transform(const PacketFramer()).toList();
      expect(batches.single.single.payload, equals(payload));
    });
  });

  group('reading', () {
    late StreamController<List<Packet>> source;
    late PacketReader reader;

    Packet packet(int n) => Packet(n, _bytes([n]));

    setUp(() {
      source = StreamController<List<Packet>>();
      reader = PacketReader(source.stream);
    });

    test('there is nothing to poll before anything arrives', () {
      expect(reader.poll(), isNull);
    });

    test('next waits for a packet', () async {
      final next = reader.next();
      source.add([packet(1)]);
      expect((await next).payload, equals([1]));
    });

    test('the packets of a batch can be polled in order', () async {
      final next = reader.next();
      source.add([packet(1), packet(2), packet(3)]);
      expect((await next).payload, equals([1]));
      expect(reader.poll()!.payload, equals([2]));
      expect(reader.poll()!.payload, equals([3]));
      expect(reader.poll(), isNull);
      expect(reader.lastSequenceId, equals(3));
    });

    test('packets which arrive before they are asked for are kept', () async {
      source.add([packet(1)]);
      source.add([packet(2)]);
      await pumpEventQueue();
      expect((await reader.next()).payload, equals([1]));
      expect((await reader.next()).payload, equals([2]));
    });

    test('stops listening while nobody is reading', () async {
      source.add([packet(1)]);
      await pumpEventQueue();
      expect(source.isPaused, isTrue);
      await reader.next();
      final next = reader.next();
      await pumpEventQueue();
      expect(source.isPaused, isFalse);
      source.add([packet(2)]);
      await next;
    });

    test('the end of the stream is a closed socket', () async {
      final next = reader.next();
      await source.close();
      await expectLater(next, throwsA(isA<SocketException>()));
      expect(reader.isClosed, isTrue);
    });

    test('what arrived before the end can still be read', () async {
      source.add([packet(1)]);
      await pumpEventQueue();
      unawaited(source.close());
      expect((await reader.next()).payload, equals([1]));
      await expectLater(reader.next(), throwsA(isA<SocketException>()));
    });

    test('an error on the stream is thrown to the reader', () async {
      final next = reader.next();
      source.addError(const OSError('broken'));
      await expectLater(next, throwsA(isA<OSError>()));
    });

    test('failing the reader fails whoever is waiting', () async {
      final next = reader.next();
      reader.fail(const OSError('broken pipe'), StackTrace.current);
      await expectLater(next, throwsA(isA<OSError>()));
      expect(reader.isClosed, isTrue);
    });

    test('what arrived before a failure can still be read', () async {
      source.add([packet(1)]);
      await pumpEventQueue();
      reader.fail(const OSError('broken pipe'), StackTrace.current);
      expect((await reader.next()).payload, equals([1]));
      await expectLater(reader.next(), throwsA(isA<OSError>()));
    });

    test('closing the reader fails whoever is waiting', () async {
      final next = reader.next();
      reader.close();
      await expectLater(next, throwsA(isA<SocketException>()));
    });
  });
}
