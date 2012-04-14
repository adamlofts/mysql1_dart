interface Transport {
  Dynamic connect([String host, int port, String user, String password, String db]);
  Dynamic processHandler(Handler handler, [bool resetPacket, bool noResponse]);
  void close();
}

