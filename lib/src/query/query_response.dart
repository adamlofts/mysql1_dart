library mysql1.query_response;

import 'dart:typed_data';

import '../constants.dart';
import '../mysql_exception.dart';
import '../mysql_protocol_error.dart';
import '../payload.dart';
import '../protocol_connection.dart';
import '../results/field.dart';
import '../results/row.dart';
import '../results/schema.dart';
import 'standard_data_packet.dart';

/// What a query sent back, with the rows still as they came off the wire.
///
/// Decoding is left until the whole response has been read. A value which
/// cannot be decoded then fails the query like any other exception, and the
/// connection is not left part way through a response.
class QueryResponse {
  final int? insertId;
  final int? affectedRows;
  final ResultSchema schema;
  final List<Uint8List> _rows;

  QueryResponse.ok(this.insertId, this.affectedRows)
      : schema = ResultSchema(const []),
        _rows = const [];

  QueryResponse.rows(List<ResultSchemaColumn> fields, this._rows)
      : schema = ResultSchema(fields),
        insertId = null,
        affectedRows = null;

  List<ResultSchemaColumn> get fields => schema.columns;

  List<ResultRow> decodeRows() => [
        for (final row in _rows) StandardDataPacket(row, schema),
      ];
}

/// Whether [payload] is the eof packet which ends the column definitions and
/// the rows.
///
/// A row can start with the same byte: it is also the marker for a value of
/// 16MB or more. An eof packet is never that long.
bool _isEof(Uint8List payload) =>
    payload.isNotEmpty && payload[0] == Packet.eof && payload.length < 9;

bool _isError(Uint8List payload) =>
    payload.isNotEmpty && payload[0] == Packet.error;

/// Whether [serverStatus], from an ok or eof packet, says another result
/// follows this one.
bool _moreResults(int serverStatus) =>
    serverStatus & ServerStatus.moreResults.bit != 0;

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
  final request = Uint8List(sql.length + 1);
  request[0] = Command.query.code;
  request.setRange(1, request.length, sql);
  conn.send(request);

  QueryResponse? first;
  while (true) {
    final payload = (await conn.next()).payload;
    if (payload.isEmpty) {
      throw createMySqlProtocolError('Empty packet in response to a query');
    }
    if (_isError(payload)) {
      throw createMySqlException(payload);
    }

    var moreResults = false;
    if (payload[0] == Packet.ok) {
      // The marker, the affected rows, the insert id, then the status. The
      // warning count and message after that are not kept.
      final ok = PayloadReader(payload)..skip(1);
      final affectedRows = ok.readLengthEncodedInt();
      final insertId = ok.readLengthEncodedInt();
      first ??= QueryResponse.ok(insertId, affectedRows);
      moreResults = _moreResults(ok.readUint16());
    } else {
      final fieldCount = PayloadReader(payload).readLengthEncodedInt();
      if (fieldCount == null) {
        throw createMySqlProtocolError(
            'Unexpected packet type ${payload[0]} in response to a query');
      }
      final fields = <ResultSchemaColumn>[];
      for (var i = 0; i < fieldCount; i++) {
        final field = (await conn.next()).payload;
        fields.add(ResultSchemaColumn(field));
      }
      // The column definitions end with an eof packet, and then the rows
      // start.
      final endOfColumns = (await conn.next()).payload;
      if (!_isEof(endOfColumns)) {
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
          throw createMySqlException(row);
        }
        if (_isEof(row)) {
          // The marker, the warning count, then the status.
          final serverStatus =
              row.length >= 5 ? (PayloadReader(row)..skip(3)).readUint16() : 0;
          moreResults = _moreResults(serverStatus);
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
