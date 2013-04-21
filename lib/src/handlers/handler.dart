part of sqljocky;

/**
 * Each command which the mysql protocol implements is handled with a [Handler] object.
 * A handler is created with the appropriate parameters when the command is invoked
 * from the connection. The transport is then responsible for sending the
 * request which the handler creates, and then parsing the result returned by 
 * the mysql server, either synchronously or asynchronously.
 */
abstract class _Handler {
  Logger log;
  bool _finished = false;
  
  /**
   * Returns a [Buffer] containing the command packet.
   */
  _Buffer createRequest();
  
  /**
   * Parses a [Buffer] containing the response to the command.
   * Returns a [Handler] if that handler should take over and
   * process subsequent packets from the server, otherwise the
   * result is returned in the [Future], either in one of the
   * Connection methods, or Transport.connect() 
   */
  dynamic processResponse(_Buffer response);
  
  /**
   * Parses the response packet to recognise Ok and Error packets.
   * Returns an [OkPacket] if the packet was an Ok packet, throws
   * a [MySqlException] if it was an Error packet, or returns [:null:] 
   * if the packet has not been handled by this method.
   */
  dynamic checkResponse(_Buffer response, [bool prepareStmt=false]) {
    if (response[0] == PACKET_OK) {
      if (prepareStmt) {
        var okPacket = new _PrepareOkPacket(response);
        log.fine(okPacket.toString());
        return okPacket;
      } else {
        var okPacket = new _OkPacket(response);
        log.fine(okPacket.toString());
        return okPacket;
      }
    } else if (response[0] == PACKET_ERROR) {
      throw new MySqlException._(response);
    }
    return null;
  }

  /**
   * When [finished] is true, this handler has finished processing responses.
   */
  bool get finished => _finished;
}
