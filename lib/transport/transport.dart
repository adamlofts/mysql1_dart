/**
 * The [Transport] and [Handler] system is designed so that, if there were blocking reads in dart,
 * these interfaces could remain the same as they are at the moment. The main change would be that
 * the [Connection] would return values immediately, instead of in [Future]s. 
 */ 
interface Transport default AsyncTransport {
  Transport();
  // TODO: host/port etc probably should be in the interface, since some transports
  // TODO: may use other parameters
  Future connect(String host, int port, String user, String password, String db);
  /**
   * Processes a handler, from sending the initial request to handling any packets returned from
   * mysql (unless [noResponse] is true).
   *
   * Returns a future
   */
  Future processHandler(Handler handler, [bool noResponse]);
  void close();
}

