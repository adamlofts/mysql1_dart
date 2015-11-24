library sqljocky.prepared_statements_test;

import 'package:test/test.dart';

import 'package:sqljocky/constants.dart';
import 'package:sqljocky/sqljocky.dart';

import 'package:sqljocky/src/buffer.dart';
import 'package:sqljocky/src/results/field_impl.dart';
import 'package:sqljocky/src/prepared_statements/binary_data_packet.dart';

void main() {
  group('read fields:', () {
    test('can read a tiny BLOB', () {
      var dataPacket = new BinaryDataPacket.forTests(null, null);
      var buffer = new Buffer.fromList([3, 65, 66, 67]);
      var field = new FieldImpl.forTests(FIELD_TYPE_BLOB);
      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals("ABC"));
    });

    test('can read a very tiny BLOB', () {
      var dataPacket = new BinaryDataPacket.forTests(null, null);
      var buffer = new Buffer.fromList([0]);
      var field = new FieldImpl.forTests(FIELD_TYPE_BLOB);
      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals(""));
    });

    test('can read a several BLOBs', () {
      var dataPacket = new BinaryDataPacket.forTests(null, null);
      var buffer = new Buffer.fromList([0, 3, 65, 66, 67, 1, 65, 0, 0, 1, 65]);
      var field = new FieldImpl.forTests(FIELD_TYPE_BLOB);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals(""));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals("ABC"));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals("A"));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals(""));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals(""));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals("A"));
    });

    test('can read TINYs', () {
      var dataPacket = new BinaryDataPacket.forTests(null, null);
      var buffer = new Buffer.fromList([0, 3, 65]);
      var field = new FieldImpl.forTests(FIELD_TYPE_TINY);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(0));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(3));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(65));
    });

    test('can read SHORTs', () {
      var dataPacket = new BinaryDataPacket.forTests(null, null);
      var buffer = new Buffer.fromList([0, 0, 255, 255, 255, 0]);
      var field = new FieldImpl.forTests(FIELD_TYPE_SHORT);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(0));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(-1));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(255));
    });

    test('can read INT24s', () {
      var dataPacket = new BinaryDataPacket.forTests(null, null);
      var buffer =
          new Buffer.fromList([0, 0, 0, 0, 255, 255, 255, 255, 255, 0, 0, 0]);
      var field = new FieldImpl.forTests(FIELD_TYPE_INT24);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(0));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(-1));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(255));
    });

    test('can read LONGs', () {
      var dataPacket = new BinaryDataPacket.forTests(null, null);
      var buffer =
          new Buffer.fromList([0, 0, 0, 0, 255, 255, 255, 255, 255, 0, 0, 0]);
      var field = new FieldImpl.forTests(FIELD_TYPE_LONG);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(0));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(-1));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(255));
    });

    test('can read LONGLONGs', () {
      var dataPacket = new BinaryDataPacket.forTests(null, null);
      var buffer = new Buffer.fromList([
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        0,
        0,
        0,
        0,
        0,
        0,
        0
      ]);
      var field = new FieldImpl.forTests(FIELD_TYPE_LONGLONG);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(0));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(-1));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(255));
    });

    test('can read NEWDECIMALs', () {
      var dataPacket = new BinaryDataPacket.forTests(null, null);
      var buffer = new Buffer.fromList([5, 0x31, 0x33, 0x2E, 0x39, 0x33]);
      var field = new FieldImpl.forTests(FIELD_TYPE_NEWDECIMAL);

      var value = dataPacket.readField(field, buffer);
      expect(value is num, equals(true));
      expect(value, equals(13.93));
    });

    //test FLOAT
    //test DOUBLE

    test('can read BITs', () {
      var dataPacket = new BinaryDataPacket.forTests(null, null);
      var buffer = new Buffer.fromList([
        1,
        123,
        20,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x00,
        0x11,
        0x12,
        0x13,
        0x14,
        0x15,
        0x16,
        0x17,
        0x18,
        0x19,
        0x10
      ]);
      var field = new FieldImpl.forTests(FIELD_TYPE_BIT);

      var value = dataPacket.readField(field, buffer);
      expect(value is num, equals(true));
      expect(value, equals(123));

      value = dataPacket.readField(field, buffer);
      expect(value is num, equals(true));
      expect(value, equals(0x0102030405060708090011121314151617181910));
    });
  });
}
