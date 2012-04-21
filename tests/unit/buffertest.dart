void runBufferTests() {
  group('buffer:', () {
    test('can write byte to buffer', () {
      Buffer buffer = new Buffer(1);
      buffer.writeByte(15);
      buffer.list[0] == 15;
    });
  });
}
