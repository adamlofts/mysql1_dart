class ClientAuthPacket {
  ClientAuthPacket(int clientFlags, int maxPacketSize, String user,
    List scrambleBuffer) {
    
  }
}

class HandshakePacket {
  int protocolVersion;
  String serverVersion;
  int threadId;
  List scrambleBuffer;
  List restOfScrambleBuffer;
  int serverCapabilities;
  int serverLanguage;
  int serverStatus;
  int scrambleLength;
  
  HandshakePacket(Buffer buffer) {
    buffer.seek(0);
    protocolVersion = buffer.readByte();
    serverVersion = buffer.readNullTerminatedString();
    threadId = buffer.readInt32();
    scrambleBuffer = buffer.readList(8);
    buffer.skip(1);
    serverCapabilities = buffer.readInt16();
    serverLanguage = buffer.readByte();
    serverStatus = buffer.readInt16();
//    serverCapabilities += buffer.readInt16() << 16;
//    restOfScrambleBuffer = buffer.readNullTerminatedList();
  }
  
  void show() {
    print("protocol version $protocolVersion");
    print("server version $serverVersion");
    print("thread id $threadId");
    print("scramble buffer $scrambleBuffer");
    print("server capabilities $serverCapabilities");
    print("server language $serverLanguage");
    print("server status $serverStatus");
  }
}

