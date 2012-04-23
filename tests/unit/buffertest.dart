void runBufferTests() {
  group('buffer:', () {
    test('can write byte to buffer', () {
      Buffer buffer = new Buffer(1);
      buffer.writeByte(15);
      expect(15).equals(buffer.list[0]);
    });
    
    test('can write int16 to buffer', () {
      Buffer buffer = new Buffer(2);
      buffer.writeInt16(12345);
      expect(0x39).equals(buffer.list[0]);
      expect(0x30).equals(buffer.list[1]);
    });
    
    test('can read int16 from buffer', () {
      Buffer buffer = new Buffer(2);
      buffer.list[0] = 0x39;
      buffer.list[1] = 0x30;
      expect(12345).equals(buffer.readInt16());
    });
  });
}
