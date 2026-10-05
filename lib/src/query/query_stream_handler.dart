// ignore_for_file: return_of_invalid_type, strong_mode_implicit_dynamic_return, strong_mode_implicit_dynamic_parameter, invalid_assignment, strong_mode_implicit_dynamic_variable

library mysql1.query_stream_handler;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import '../constants.dart';
import '../buffer.dart';

import '../handlers/handler.dart';
import '../handlers/ok_packet.dart';
import '../mysql_exception.dart';

import '../results/row.dart';
import '../results/field.dart';
import '../results/results_impl.dart';

import 'result_set_header_packet.dart';
import 'standard_data_packet.dart';

class QueryStreamHandler extends Handler {
  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;
  final String _sql;
  int _state = STATE_HEADER_PACKET;

  OkPacket? _okPacket;
  ResultSetHeaderPacket? _resultSetHeaderPacket;
  final List<Field> fieldPackets = <Field>[];

  StreamController<ResultRow>? _streamController;

  /// Whether the result has been handed to the caller.
  ///
  /// The response to CALL is every result set the procedure selects and then
  /// an ok packet for the call itself. The first of them is the result; what
  /// follows is read and dropped, because all of it has to be off the wire
  /// before the next request goes out. The row stream of the result stays open
  /// until then, since its closing is what tells the connection it is free.
  bool _resultSent = false;

  /// Whether the result set being read is one which follows the result.
  bool _discarding = false;

  QueryStreamHandler(this._sql) : super(Logger('QueryStreamHandler'));

  @override
  Buffer createRequest() {
    var encoded = utf8.encode(_sql);
    var buffer = Buffer(encoded.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeList(encoded);
    return buffer;
  }

  @override
  HandlerResponse processResponse(Buffer response) {
    log.fine('Processing query response');
    final controller = _streamController;
    if (response[0] == PACKET_ERROR && controller != null) {
      // The caller already has the result, so the error can only reach it
      // through the rows.
      controller.addError(createMySqlException(response));
      controller.close();
      return HandlerResponse(finished: true);
    }
    var packet = checkResponse(response, _state == STATE_ROW_PACKETS);
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        if (_state == STATE_FIELD_PACKETS) {
          return _handleEndOfFields();
        } else if (_state == STATE_ROW_PACKETS) {
          return _handleEndOfRows(response);
        }
      } else {
        switch (_state) {
          case STATE_HEADER_PACKET:
            _handleHeaderPacket(response);
            break;
          case STATE_FIELD_PACKETS:
            _handleFieldPacket(response);
            break;
          case STATE_ROW_PACKETS:
            _handleRowPacket(response);
            break;
        }
      }
    } else if (packet is OkPacket) {
      return _handleOkPacket(packet);
    }
    return HandlerResponse.notFinished;
  }

  HandlerResponse _handleEndOfFields() {
    _state = STATE_ROW_PACKETS;
    if (_resultSent) {
      _discarding = true;
      return HandlerResponse.notFinished;
    }
    _resultSent = true;
    _streamController = StreamController<ResultRow>(onCancel: () {
      _streamController!.close();
    });
    return HandlerResponse(
        result: ResultsStream(null, null, fieldPackets,
            stream: _streamController!.stream));
  }

  HandlerResponse _handleEndOfRows(Buffer response) {
    // An eof packet is the marker, two bytes of warning count, then the status.
    final serverStatus =
        response.length >= 5 ? response[3] | (response[4] << 8) : 0;
    if ((serverStatus & SERVER_MORE_RESULTS_EXISTS) != 0) {
      _state = STATE_HEADER_PACKET;
      return HandlerResponse.notFinished;
    }
    // the connection's _handler field needs to have been nulled out before the stream is closed,
    // otherwise the stream will be reused in an unfinished state.
    // TODO: can we use Future.delayed elsewhere, to make reusing connections nicer?
//    Future.delayed(Duration(seconds: 0), _streamController.close);
    _streamController?.close();
    return HandlerResponse(finished: true);
  }

  void _handleHeaderPacket(Buffer response) {
    _resultSetHeaderPacket = ResultSetHeaderPacket(response);
    log.fine(_resultSetHeaderPacket.toString());
    _state = STATE_FIELD_PACKETS;
  }

  void _handleFieldPacket(Buffer response) {
    if (_resultSent) {
      return;
    }
    var fieldPacket = Field(response);
    log.fine(fieldPacket.toString());
    fieldPackets.add(fieldPacket);
  }

  void _handleRowPacket(Buffer response) {
    if (_discarding) {
      return;
    }
    var dataPacket = StandardDataPacket(response, fieldPackets);
    log.fine(dataPacket.toString());
    _streamController?.add(dataPacket);
  }

  HandlerResponse _handleOkPacket(OkPacket packet) {
    final moreResults = (packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) != 0;
    if (_resultSent) {
      if (moreResults) {
        return HandlerResponse.notFinished;
      }
      _streamController?.close();
      return HandlerResponse(finished: true);
    }
    _okPacket = packet;
    var finished = false;
    // TODO: I think this is to do with multiple queries. Will probably break.
    if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
      finished = true;
    }

    //TODO is this finished value right?
    return HandlerResponse(
        finished: finished,
        result: ResultsStream(
            _okPacket!.insertId, _okPacket!.affectedRows, fieldPackets));
  }

  @override
  String toString() {
    return 'QueryStreamHandler($_sql)';
  }
}
