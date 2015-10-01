part of sqljocky;

void runBufferTests() {
  group('buffer:', () {
    test('can write byte to buffer', () {
      var buffer = new Buffer(1);
      buffer.writeByte(15);
      expect(buffer.list[0], equals(15));
    });

    test('can write int16 to buffer', () {
      var buffer = new Buffer(2);
      buffer.writeInt16(12345);
      expect(buffer.list[0], equals(0x39));
      expect(buffer.list[1], equals(0x30));
    });

    test('can read int16 from buffer', () {
      var buffer = new Buffer(2);
      buffer.list[0] = 0x39;
      buffer.list[1] = 0x30;
      expect(buffer.readInt16(), equals(12345));
    });

    test('knows if there is no more data available', () {
      var buffer = new Buffer(2);
      buffer.readInt16();
      expect(buffer.hasMore, isFalse);
    });

    test('knows if there is more data available', () {
      var buffer = new Buffer(3);
      buffer.readInt16();
      expect(buffer.hasMore, isTrue);
    });
  });
}
