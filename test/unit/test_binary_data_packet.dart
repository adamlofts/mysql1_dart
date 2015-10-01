part of sqljocky;

void runBinaryDataPacketTests() {
  group('buffer:', () {
    test('can read short blob', () {
      var packet = new _BinaryDataPacket._forTests(null, null);
      var field = new _FieldImpl._forTests(FIELD_TYPE_BLOB);
      var buffer = new Buffer.fromList([1, 32]);
      var value = packet._readField(field, buffer);

      expect(value, new isInstanceOf<Blob>());
      expect((value as Blob).toString(), equals(" "));
    });

    test('can read long blob', () {
      var packet = new _BinaryDataPacket._forTests(null, null);
      var field = new _FieldImpl._forTests(FIELD_TYPE_BLOB);

      var buffer = new Buffer(500 + 3);
      buffer.writeLengthCodedBinary(500);
      for (int i = 0; i < 500; i++) {
        buffer.writeByte(32);
      }
      var value = packet._readField(field, buffer);

      expect(value, new isInstanceOf<Blob>());
      expect((value as Blob).toString(), hasLength(500));
    });

    test('can read very long blob', () {
      var packet = new _BinaryDataPacket._forTests(null, null);
      var field = new _FieldImpl._forTests(FIELD_TYPE_BLOB);

      var buffer = new Buffer(50000 + 3);
      buffer.writeLengthCodedBinary(50000);
      for (int i = 0; i < 50000; i++) {
        buffer.writeByte(32);
      }
      var value = packet._readField(field, buffer);

      expect(value, new isInstanceOf<Blob>());
      expect((value as Blob).toString(), hasLength(50000));
    });
  });
}
