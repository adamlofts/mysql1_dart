void runBufferTests() {
  group('buffer:', () {
    test('can write byte to buffer', () {
      Buffer buffer = new Buffer(1);
      buffer.writeByte(15);
      Expect.equals(15, buffer.list[0]);
    });
    
    test('can write int16 to buffer', () {
      Buffer buffer = new Buffer(2);
      buffer.writeInt16(12345);
      Expect.equals(0x39, buffer.list[0]);
      Expect.equals(0x30, buffer.list[1]);
    });
    
    test('can read int16 from buffer', () {
      Buffer buffer = new Buffer(2);
      buffer.list[0] = 0x39;
      buffer.list[1] = 0x30;
      Expect.equals(12345, buffer.readInt16());
    });
  });
}
