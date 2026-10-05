library mysql1.test.large_packet_test;

import 'package:test/test.dart';

import '../test_infrastructure.dart';

/// The most a single packet can carry. A longer payload is split, and one
/// which is an exact multiple of this is ended with an empty packet.
const maxPacketPayload = 0xffffff;

// https://github.com/adamlofts/mysql1_dart/issues/59
void main() {
  initializeTest();

  /// Select a string of [length] characters, or return null if the server is
  /// not configured to send one that long.
  Future<String?> selectString(int length) async {
    var results = await conn.query('select @@max_allowed_packet');
    if ((results.first[0] as int) < length + 1024) {
      return null;
    }
    results = await conn.query("select repeat('a', $length) as s");
    return results.first['s'].toString();
  }

  test('a row which exactly fills a packet', () async {
    // The row is the value and the four bytes of its length.
    final length = maxPacketPayload - 4;
    final s = await selectString(length);
    if (s == null) {
      markTestSkipped('max_allowed_packet is too small');
      return;
    }
    expect(s.length, equals(length));

    var results = await conn.query('select 99 as answer');
    expect(results.single['answer'], equals(99));
  });

  test('a row which is split across packets', () async {
    final length = maxPacketPayload + 1000;
    final s = await selectString(length);
    if (s == null) {
      markTestSkipped('max_allowed_packet is too small');
      return;
    }
    expect(s.length, equals(length));

    var results = await conn.query('select 99 as answer');
    expect(results.single['answer'], equals(99));
  });
}
