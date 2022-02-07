library mysql1.binary_data_packet_test;

import 'package:mysql1/mysql1.dart';
import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/prepared_statements/binary_data_packet.dart';

import 'package:test/test.dart';

void main() {
  group('buffer:', () {
    test('can read short blob', () {
      var packet = BinaryDataPacket.forTests(null);
      var field = Field.forTests(FIELD_TYPE_BLOB);
      var buffer = Buffer.fromList([1, 32]);
      var value = packet.readField(field, buffer);

      expect(value, TypeMatcher<Blob>());
      expect((value as Blob).toString(), equals(' '));
    });

    test('can read long blob', () {
      var packet = BinaryDataPacket.forTests(null);
      var field = Field.forTests(FIELD_TYPE_BLOB);

      var buffer = Buffer(500 + 3);
      buffer.writeLengthCodedBinary(500);
      for (var i = 0; i < 500; i++) {
        buffer.writeByte(32);
      }
      var value = packet.readField(field, buffer);

      expect(value, TypeMatcher<Blob>());
      expect((value as Blob).toString(), hasLength(500));
    });

    test('can read very long blob', () {
      var packet = BinaryDataPacket.forTests(null);
      var field = Field.forTests(FIELD_TYPE_BLOB);

      var buffer = Buffer(50000 + 3);
      buffer.writeLengthCodedBinary(50000);
      for (var i = 0; i < 50000; i++) {
        buffer.writeByte(32);
      }
      var value = packet.readField(field, buffer);

      expect(value, TypeMatcher<Blob>());
      expect((value as Blob).toString(), hasLength(50000));
    });
  });
}
