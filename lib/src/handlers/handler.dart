library mysql1.handler;

import 'package:logging/logging.dart';

import '../constants.dart';
import '../buffer.dart';
import '../mysql_exception.dart';
import '../prepared_statements/prepare_ok_packet.dart';
import 'ok_packet.dart';

class _NoResult {
  const _NoResult();
}

const _NO_RESULT = _NoResult();

/// Represents the response from a [_Handler] when [_Handler.processResponse] is
/// called. If the handler has finished processing the response, [finished] is true,
/// [nextHandler] is irrelevant and [result] contains the result to return to the
/// user. If the handler needs another handler to process the response, [finished]
/// is false, [nextHandler] contains the next handler which should process the
/// next packet from the server, and [result] is [_NO_RESULT].
class HandlerResponse {
  final bool finished;
  final Handler? nextHandler;
  final dynamic result;

  bool get hasResult => result != _NO_RESULT;

  HandlerResponse(
      {this.finished = false, this.nextHandler, this.result = _NO_RESULT});

  static final HandlerResponse notFinished = HandlerResponse();
}

/// Each command which the mysql protocol implements is handled with a [_Handler] object.
/// A handler is created with the appropriate parameters when the command is invoked
/// from the connection. The transport is then responsible for sending the
/// request which the handler creates, and then parsing the result returned by
/// the mysql server, either synchronously or asynchronously.
abstract class Handler {
  final Logger log;

  Handler(this.log);

  /// Returns a [Buffer] containing the command packet.
  Buffer createRequest();

  ///
  /// Parses a [Buffer] containing the response to the command.
  /// Returns a [_HandlerResponse].
  /// The default implementation returns a finished [_HandlerResponse] with
  /// a result which is obtained by calling [checkResponse]
  ///
  HandlerResponse processResponse(Buffer response) =>
      HandlerResponse(finished: true, result: checkResponse(response));

  ///
  /// Parses the response packet to recognise Ok and Error packets.
  /// Returns an [_OkPacket] if the packet was an Ok packet, throws
  /// a [MySqlException] if it was an Error packet, or returns [:null:]
  /// if the packet has not been handled by this method.
  ///
  dynamic checkResponse(Buffer response,
      [bool prepareStmt = false, bool isHandlingRows = false]) {
    if (response[0] == PACKET_OK && !isHandlingRows) {
      if (prepareStmt) {
        var okPacket = PrepareOkPacket(response);
        log.fine(okPacket.toString());
        return okPacket;
      } else {
        var okPacket = OkPacket(response);
        log.fine(okPacket.toString());
        return okPacket;
      }
    } else if (response[0] == PACKET_ERROR) {
      throw createMySqlException(response);
    }
    return null;
  }
}
