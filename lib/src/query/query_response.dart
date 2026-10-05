library mysql1.query_response;

import 'dart:typed_data';

import '../buffer.dart';
import '../constants.dart';
import '../handlers/ok_packet.dart';
import '../mysql_exception.dart';
import '../mysql_protocol_error.dart';
import '../protocol_connection.dart';
import '../results/field.dart';
import '../results/row.dart';
import 'standard_data_packet.dart';

/// What a query sent back, with the rows still as they came off the wire.
///
/// Decoding is left until the whole response has been read. A value which
/// cannot be decoded then fails the query like any other exception, and the
/// connection is not left part way through a response.
class QueryResponse {
  final int? insertId;
  final int? affectedRows;
  final List<Field> fields;
  final List<Uint8List> _rows;

  QueryResponse.ok(this.insertId, this.affectedRows)
      : fields = const [],
        _rows = const [];

  QueryResponse.rows(this.fields, this._rows)
      : insertId = null,
        affectedRows = null;

  List<ResultRow> decodeRows() => [
        for (final row in _rows) StandardDataPacket(Buffer.view(row), fields),
      ];
}

/// Whether [payload] is the eof packet which ends the column definitions and
/// the rows.
///
/// A row can start with the same byte: it is also the marker for a value of
/// 16MB or more. An eof packet is never that long.
bool _isEof(Uint8List payload) =>
    payload.isNotEmpty && payload[0] == PACKET_EOF && payload.length < 9;

bool _isError(Uint8List payload) =>
    payload.isNotEmpty && payload[0] == PACKET_ERROR;

/// Send [sql] and read everything the server sends back for it. Call this
/// inside [ProtocolConnection.exchange].
///
/// The response is one result for a statement, and for CALL every result set
/// the procedure selects followed by an ok packet for the call itself. Each
/// says whether another follows. The first is what is returned; the rest are
/// read, because they have to be off the wire before the next request, and
/// dropped.
///
/// Throws [MySqlException] if the server ends the response with an error,
/// wherever in it that comes.
Future<QueryResponse> runQuery(ProtocolConnection conn, List<int> sql) async {
  final request = Buffer(sql.length + 1);
  request.writeByte(COM_QUERY);
  request.writeList(sql);
  conn.send(request);

  QueryResponse? first;
  while (true) {
    final payload = (await conn.next()).payload;
    if (payload.isEmpty) {
      throw createMySqlProtocolError('Empty packet in response to a query');
    }
    if (_isError(payload)) {
      throw createMySqlException(Buffer.view(payload));
    }

    var moreResults = false;
    if (payload[0] == PACKET_OK) {
      final ok = OkPacket(Buffer.view(payload));
      first ??= QueryResponse.ok(ok.insertId, ok.affectedRows);
      moreResults = (ok.serverStatus & SERVER_MORE_RESULTS_EXISTS) != 0;
    } else {
      final fieldCount = Buffer.view(payload).readLengthCodedBinary();
      if (fieldCount == null) {
        throw createMySqlProtocolError(
            'Unexpected packet type ${payload[0]} in response to a query');
      }
      final fields = <Field>[];
      for (var i = 0; i < fieldCount; i++) {
        final field = (await conn.next()).payload;
        fields.add(Field(Buffer.view(field)));
      }
      if (!_isEof((await conn.next()).payload)) {
        throw createMySqlProtocolError(
            'Expected the column definitions to end with an eof packet');
      }

      final keep = first == null;
      final rows = <Uint8List>[];
      while (true) {
        // The one place a response is long. An await goes round the event
        // loop even for a packet which has already arrived, and a read from
        // the socket holds many rows, so take those directly: it is about 15%
        // of the time to read a large result.
        final row = (conn.poll() ?? await conn.next()).payload;
        if (_isError(row)) {
          throw createMySqlException(Buffer.view(row));
        }
        if (_isEof(row)) {
          // The marker, two bytes of warning count, then the status.
          final serverStatus = row.length >= 5 ? row[3] | (row[4] << 8) : 0;
          moreResults = (serverStatus & SERVER_MORE_RESULTS_EXISTS) != 0;
          break;
        }
        if (keep) {
          rows.add(row);
        }
      }
      first ??= QueryResponse.rows(List.unmodifiable(fields), rows);
    }

    if (!moreResults) {
      return first;
    }
  }
}
