library mysql1.test.blob_test;

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

void main() {
  initializeTest('blobs', 'create table blobs (stuff blob)');

  // 0xc3 0x28 is not valid UTF-8, so a blob which is decoded as text on the
  // way in or out would not survive the round trip.
  test('bytes which are not text come back as they went in', () async {
    await conn.query('insert into blobs (stuff) values (?)', [
      [0xc3, 0x28]
    ]);
    final results = await conn.query('select stuff from blobs');
    expect((results.first[0] as Blob).toBytes(), equals([0xc3, 0x28]));
  });
}
