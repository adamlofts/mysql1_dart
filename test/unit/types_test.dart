library types_test;

import 'package:sqljocky/sqljocky.dart';
import 'package:unittest/unittest.dart';
import 'dart:typed_data';

void runTypesTests() {
  group('types:', () {
    test('can create blob from string', () {
      var blob = new Blob.fromString("Hello");
      expect(blob, isNotNull);
    });

    test('can string blob can turn into a string', () {
      var blob = new Blob.fromString("Hello");
      expect(blob.toString(), equals("Hello"));
    });

    test('can string blob can turn into bytes', () {
      var blob = new Blob.fromString("ABC");
      var bytes = blob.toBytes();
      expect(bytes[0], equals(65));
    });

    test('can create blob from bytes', () {
      var bytes = new Uint8List(3);
      bytes[0] = 1;
      bytes[1] = 1;
      bytes[2] = 1;
      var blob = new Blob.fromBytes(bytes);
      expect(blob, isNotNull);
    });

    test('can bytes blob turn into a string', () {
      var bytes = new Uint8List(3);
      bytes[0] = 65;
      bytes[1] = 66;
      bytes[2] = 67;
      var blob = new Blob.fromBytes(bytes);
      expect(blob.toString(), "ABC");
    });

    test('can bytes blob turn into bytes', () {
      var bytes = new Uint8List(3);
      bytes[0] = 65;
      bytes[1] = 66;
      bytes[2] = 67;
      var blob = new Blob.fromBytes(bytes);
      var outBytes = blob.toBytes();
      expect(outBytes, bytes);
    });

    test('string blobs are equal', () {
      var blob1 = new Blob.fromString("ABC");
      var blob2 = new Blob.fromString("ABC");
      expect(blob1 == blob2, isTrue);
      expect(blob1.hashCode == blob2.hashCode, isTrue);
    });

    test('string blobs are not equal', () {
      var blob1 = new Blob.fromString("ABC");
      var blob2 = new Blob.fromString("ABD");
      expect(blob1 == blob2, isFalse);
      // hashCode may be equal, but probably isn't
    });

    test('byte blobs are equal', () {
      var bytes1 = new Uint8List(3);
      bytes1[0] = 65;
      bytes1[1] = 66;
      bytes1[2] = 67;
      var blob1 = new Blob.fromBytes(bytes1);
      var bytes2 = new Uint8List(3);
      bytes2[0] = 65;
      bytes2[1] = 66;
      bytes2[2] = 67;
      var blob2 = new Blob.fromBytes(bytes2);
      expect(blob1 == blob2, isTrue);
      expect(blob1.hashCode == blob2.hashCode, isTrue);
    });

    test('byte blobs are not equal', () {
      var bytes1 = new Uint8List(3);
      bytes1[0] = 65;
      bytes1[1] = 66;
      bytes1[2] = 67;
      var blob1 = new Blob.fromBytes(bytes1);
      var bytes2 = new Uint8List(3);
      bytes2[0] = 65;
      bytes2[1] = 66;
      bytes2[2] = 68;
      var blob2 = new Blob.fromBytes(bytes2);
      expect(blob1 == blob2, isFalse);
    });

    test('byte blobs equal to string blobs', () {
      var bytes1 = new Uint8List(3);
      bytes1[0] = 65;
      bytes1[1] = 66;
      bytes1[2] = 67;
      var blob1 = new Blob.fromBytes(bytes1);
      var blob2 = new Blob.fromString("ABC");
      expect(blob1 == blob2, isTrue);
      expect(blob1.hashCode == blob2.hashCode, isTrue);
    });
  });
}

void main() {
  runTypesTests();
}
