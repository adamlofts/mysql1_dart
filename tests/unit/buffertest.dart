class BufferTest {
  void canWriteByteToBuffer() {
    Buffer buffer = new Buffer(1);
    buffer.writeByte(15);
    buffer.list[0] == 15;
  }
  
  void runAll() {
    canWriteByteToBuffer();
  }
}
