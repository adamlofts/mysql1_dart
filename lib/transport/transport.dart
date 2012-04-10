interface Transport {
  Dynamic connect([String host, int port, String user, String password]);
  Dynamic processHandler(Handler handler);
  void close();
}

