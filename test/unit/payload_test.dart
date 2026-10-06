library mysql1.payload_test;

import 'dart:typed_data';

import 'package:mysql1/src/payload.dart';
import 'package:test/test.dart';

PayloadReader _reader(List<int> bytes) =>
    PayloadReader(Uint8List.fromList(bytes));

void main() {
  group('reading', () {
    test('integers are little-endian', () {
      final reader = _reader([1, 0x34, 0x12, 0x78, 0x56, 0x34, 0x12]);
      expect(reader.readByte(), equals(1));
      expect(reader.readUint16(), equals(0x1234));
      expect(reader.readUint32(), equals(0x12345678));
      expect(reader.hasMore, isFalse);
    });

    test('bytes and the rest', () {
      final reader = _reader([1, 2, 3, 4, 5]);
      expect(reader.readBytes(2), equals([1, 2]));
      expect(reader.readRest(), equals([3, 4, 5]));
      expect(reader.hasMore, isFalse);
    });

    test('skip passes over bytes', () {
      final reader = _reader([1, 2, 3])..skip(2);
      expect(reader.readByte(), equals(3));
    });

    test('strings are utf8', () {
      final reader = _reader([0xd0, 0x94, 0x61, 0x62]);
      expect(reader.readString(2), equals('Д'));
      expect(reader.readRestAsString(), equals('ab'));
    });

    test('a string which is not utf8 is read with replacements', () {
      expect(_reader([0xff, 0x61]).readRestAsString(), equals('�a'));
    });

    test('a null-terminated string stops at the zero and consumes it', () {
      final reader = _reader([0x61, 0x62, 0, 0x63]);
      expect(reader.readNullTerminatedString(), equals('ab'));
      expect(reader.readByte(), equals(0x63));
    });

    test('a null-terminated string with no end is an error', () {
      expect(() => _reader([0x61]).readNullTerminatedString(),
          throwsFormatException);
    });

    group('length-encoded integers', () {
      test('one byte below 0xfb', () {
        expect(_reader([0]).readLengthEncodedInt(), equals(0));
        expect(_reader([0xfa]).readLengthEncodedInt(), equals(0xfa));
      });

      test('0xfb is null', () {
        expect(_reader([0xfb]).readLengthEncodedInt(), isNull);
      });

      test('0xfc is two bytes', () {
        expect(
            _reader([0xfc, 0x34, 0x12]).readLengthEncodedInt(), equals(0x1234));
      });

      test('0xfd is three bytes', () {
        expect(_reader([0xfd, 0x56, 0x34, 0x12]).readLengthEncodedInt(),
            equals(0x123456));
      });

      test('0xfe is eight bytes', () {
        expect(
            _reader([0xfe, 1, 0, 0, 0, 0, 0, 0, 0x10]).readLengthEncodedInt(),
            equals(0x1000000000000001));
      });

      test('0xff is not one', () {
        expect(() => _reader([0xff]).readLengthEncodedInt(),
            throwsFormatException);
      });
    });

    test('a length-encoded string', () {
      final reader = _reader([2, 0x61, 0x62, 0xfb, 0]);
      expect(reader.readLengthEncodedString(), equals('ab'));
      expect(reader.readLengthEncodedString(), isNull);
      expect(reader.readLengthEncodedString(), equals(''));
      expect(reader.hasMore, isFalse);
    });
  });

  group('building', () {
    test('integers are little-endian', () {
      final builder = BytesBuilder()
        ..addUint16(0x1234)
        ..addUint32(0x12345678);
      expect(builder.takeBytes(), equals([0x34, 0x12, 0x78, 0x56, 0x34, 0x12]));
    });

    test('a null-terminated value and zeros', () {
      final builder = BytesBuilder()
        ..addNullTerminated([1, 2])
        ..addZeros(3);
      expect(builder.takeBytes(), equals([1, 2, 0, 0, 0, 0]));
    });

    test('what is built can be read back', () {
      final bytes = (BytesBuilder()
            ..addUint32(0xdeadbeef)
            ..addNullTerminated('hello'.codeUnits)
            ..addByte(0xfc)
            ..addUint16(300))
          .takeBytes();
      final reader = PayloadReader(bytes);
      expect(reader.readUint32(), equals(0xdeadbeef));
      expect(reader.readNullTerminatedString(), equals('hello'));
      expect(reader.readLengthEncodedInt(), equals(300));
      expect(reader.hasMore, isFalse);
    });
  });
}
