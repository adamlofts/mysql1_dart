part of sqljocky;

class _NoResult {
  const _NoResult();
}
const _NO_RESULT = const _NoResult();

class _HandlerResponse {
  final bool finished;
  final _Handler nextHandler;
  dynamic result;

  bool get hasResult => result != _NO_RESULT;

  _HandlerResponse({this.finished: false, this.nextHandler: null, this.result: _NO_RESULT});

  static final _HandlerResponse notFinished = new _HandlerResponse();
}

/**
 * Each command which the mysql protocol implements is handled with a [Handler] object.
 * A handler is created with the appropriate parameters when the command is invoked
 * from the connection. The transport is then responsible for sending the
 * request which the handler creates, and then parsing the result returned by 
 * the mysql server, either synchronously or asynchronously.
 */
abstract class _Handler {
  Logger log;

  /**
   * Returns a [Buffer] containing the command packet.
   */
  Buffer createRequest();
  
  /**
   * Parses a [Buffer] containing the response to the command.
   * Returns a [Handler] if that handler should take over and
   * process subsequent packets from the server, otherwise the
   * result is returned in the [Future], either in one of the
   * Connection methods, or Transport.connect() 
   */
  _HandlerResponse processResponse(Buffer response);
  
  /**
   * Parses the response packet to recognise Ok and Error packets.
   * Returns an [OkPacket] if the packet was an Ok packet, throws
   * a [MySqlException] if it was an Error packet, or returns [:null:] 
   * if the packet has not been handled by this method.
   */
  dynamic checkResponse(Buffer response, [bool prepareStmt=false]) {
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
}
