library mysql1.query_response_test;

import 'dart:convert';

import 'package:mysql1/mysql1.dart' show MySqlException;
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/query/query_response.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

const _timeout = Duration(seconds: 5);

List<int> _lengthCoded(String s) => [s.length, ...utf8.encode(s)];

/// A column definition for a column called [name] of [type].
List<int> _field(String name, int type) => [
      ..._lengthCoded('def'),
      ..._lengthCoded('db'),
      ..._lengthCoded('t'),
      ..._lengthCoded('t'),
      ..._lengthCoded(name),
      ..._lengthCoded(name),
      0x0c, // length of the fixed fields
      0x21, 0, // character set
      11, 0, 0, 0, // column length
      type,
      0, 0, // flags
      0, // decimals
      0, 0, // filler
    ];

/// A row of text protocol [values].
List<int> _row(List<String> values) =>
    [for (final v in values) ..._lengthCoded(v)];

/// The eof packet which ends the column definitions and the rows.
List<int> _eof({bool moreResults = false}) =>
    [PACKET_EOF, 0, 0, moreResults ? SERVER_MORE_RESULTS_EXISTS : 0, 0];

/// An ok packet: no rows affected, no insert id, then the status.
List<int> _ok({int affectedRows = 0, bool moreResults = false}) => [
      PACKET_OK,
      affectedRows,
      0,
      moreResults ? SERVER_MORE_RESULTS_EXISTS : 0,
      0,
      0,
      0
    ];

/// An error packet: the marker, error 1146, and a state and message.
final _error = [0xff, 0x7a, 0x04, ...'#42S02No such table'.codeUnits];

/// A result set of one int column called n holding [values].
List<List<int>> _resultSet(List<String> values, {bool moreResults = false}) => [
      [1], // one column
      _field('n', FIELD_TYPE_LONG),
      _eof(),
      for (final v in values) _row([v]),
      _eof(moreResults: moreResults),
    ];

void main() {
  late FakeServer server;

  setUp(() async {
    server = await FakeServer.start();
  });

  tearDown(() => server.close());

  /// Run a query and answer it with [response].
  Future<QueryResponse> query(List<List<int>> response) async {
    final client = server.client;
    final result = client.exchange(
        () => runQuery(client, utf8.encode('select n from t')), _timeout);
    final request = await server.nextRequest();
    expect(request.payload.first, equals(COM_QUERY));
    expect(utf8.decode(request.payload.sublist(1)), equals('select n from t'));
    server.send(response);
    return result;
  }

  /// Check the response was read to its end: the next exchange is answered
  /// with its own reply and not with something left behind.
  Future<void> expectWireIsClean() async {
    final response = await query([_ok(affectedRows: 7)]);
    expect(response.affectedRows, equals(7));
  }

  test('a statement which returns no rows', () async {
    final response = await query([_ok(affectedRows: 3)]);
    expect(response.affectedRows, equals(3));
    expect(response.fields, isEmpty);
    expect(response.decodeRows(), isEmpty);
  });

  test('a result set', () async {
    final response = await query(_resultSet(['1', '2']));
    expect(response.fields.single.name, equals('n'));
    expect(response.decodeRows().map((r) => r[0]), equals([1, 2]));
    await expectWireIsClean();
  });

  test('a row knows its columns', () async {
    final response = await query([
      [2],
      _field('n', FIELD_TYPE_LONG),
      _field('m', FIELD_TYPE_LONG),
      _eof(),
      // The value 1, and the marker for null.
      [1, 0x31, 0xfb],
      _eof(),
    ]);
    expect(
        response.schema.columns.map((c) => c.columnName), equals(['n', 'm']));

    final row = response.decodeRows().single;
    expect(row.schema, same(response.schema));
    expect(row.toColumnMap(), equals({'n': 1, 'm': null}));
    expect(row.isSqlNull(0), isFalse);
    expect(row.isSqlNull(1), isTrue);
  });

  test('an error', () async {
    await expectLater(query([_error]),
        throwsA(isA<MySqlException>().having((e) => e.errorNumber, '', 1146)));
    await expectWireIsClean();
  });

  // The marker for a value of 16MB or more is the byte an eof packet starts
  // with. What tells them apart is that an eof packet is short.
  test('a row which starts with the eof marker is a row', () async {
    final response = await query([
      [1],
      _field('n', FIELD_TYPE_LONG),
      _eof(),
      // The value 7, with its length written in the eight byte form.
      [PACKET_EOF, 1, 0, 0, 0, 0, 0, 0, 0, 0x37],
      _eof(),
    ]);
    expect(response.decodeRows().map((r) => r[0]), equals([7]));
  });

  group('a row which cannot be decoded', () {
    test('is read like any other', () async {
      await query(_resultSet(['1', 'abc', '2']));
      await expectWireIsClean();
    });

    test('fails when the rows are decoded', () async {
      final response = await query(_resultSet(['1', 'abc', '2']));
      expect(response.decodeRows, throwsFormatException);
    });
  });

  // What CALL sends back: the result sets the procedure selects, then an ok
  // packet for the call itself.
  group('a response with several results', () {
    test('returns the first and reads the rest', () async {
      final response = await query([
        ..._resultSet(['1', '2'], moreResults: true),
        ..._resultSet(['10'], moreResults: true),
        _ok(),
      ]);
      expect(response.decodeRows().map((r) => r[0]), equals([1, 2]));
      await expectWireIsClean();
    });

    test('returns the first when that is not a result set', () async {
      final response = await query([
        _ok(affectedRows: 4, moreResults: true),
        ..._resultSet(['10'], moreResults: true),
        _ok(),
      ]);
      expect(response.affectedRows, equals(4));
      expect(response.decodeRows(), isEmpty);
      await expectWireIsClean();
    });

    test('fails if a later one is an error', () async {
      await expectLater(
          query([
            ..._resultSet(['1'], moreResults: true),
            _error,
          ]),
          throwsA(isA<MySqlException>()));
      await expectWireIsClean();
    });
  });

  test('an error part way through the rows', () async {
    await expectLater(
        query([
          [1],
          _field('n', FIELD_TYPE_LONG),
          _eof(),
          _row(['1']),
          _error,
        ]),
        throwsA(isA<MySqlException>()));
    await expectWireIsClean();
  });
}
