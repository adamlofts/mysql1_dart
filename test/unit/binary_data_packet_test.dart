library sqljocky.binary_data_packet_test;

import 'package:sqljocky5/sqljocky.dart';
import 'package:sqljocky5/constants.dart';
import 'package:sqljocky5/src/buffer.dart';
import 'package:sqljocky5/src/prepared_statements/binary_data_packet.dart';
import 'package:sqljocky5/src/results/field_impl.dart';

import 'package:test/test.dart';

void main() {
  group('buffer:', () {
    test('can read short blob', () {
      var packet = new BinaryDataPacket.forTests(null, null);
      var field = new FieldImpl.forTests(FIELD_TYPE_BLOB);
      var buffer = new Buffer.fromList([1, 32]);
      var value = packet.readField(field, buffer);

      expect(value, new isInstanceOf<Blob>());
      expect((value as Blob).toString(), equals(" "));
    });

    test('can read long blob', () {
      var packet = new BinaryDataPacket.forTests(null, null);
      var field = new FieldImpl.forTests(FIELD_TYPE_BLOB);

      var buffer = new Buffer(500 + 3);
      buffer.writeLengthCodedBinary(500);
      for (int i = 0; i < 500; i++) {
        buffer.writeByte(32);
      }
      var value = packet.readField(field, buffer);

      expect(value, new isInstanceOf<Blob>());
      expect((value as Blob).toString(), hasLength(500));
    });

    test('can read very long blob', () {
      var packet = new BinaryDataPacket.forTests(null, null);
      var field = new FieldImpl.forTests(FIELD_TYPE_BLOB);

      var buffer = new Buffer(50000 + 3);
      buffer.writeLengthCodedBinary(50000);
      for (int i = 0; i < 50000; i++) {
        buffer.writeByte(32);
      }
      var value = packet.readField(field, buffer);

      expect(value, new isInstanceOf<Blob>());
      expect((value as Blob).toString(), hasLength(50000));
    });
  });
}
