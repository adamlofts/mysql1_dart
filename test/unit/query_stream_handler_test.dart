library mysql1.query_stream_handler_test;

import 'dart:convert';

import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/query/query_stream_handler.dart';
import 'package:mysql1/src/results/results_impl.dart';

import 'package:test/test.dart';

List<int> _lengthCoded(String s) => [s.length, ...utf8.encode(s)];

/// A column definition for a column called [name] of [type].
Buffer _field(String name, int type) => Buffer.fromList([
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
    ]);

/// A row of text protocol [values].
Buffer _row(List<String> values) =>
    Buffer.fromList([for (final v in values) ..._lengthCoded(v)]);

/// The eof packet which ends the column definitions and the rows.
Buffer _eof() => Buffer.fromList([PACKET_EOF, 0, 0, 0, 0]);

void main() {
  group('a row which cannot be decoded', () {
    late QueryStreamHandler handler;
    late ResultsStream results;

    setUp(() {
      handler = QueryStreamHandler('select n from t');
      handler.processResponse(Buffer.fromList([1])); // one column
      handler.processResponse(_field('n', FIELD_TYPE_LONG));
      results = handler.processResponse(_eof()).result as ResultsStream;
    });

    test('does not throw out of the handler', () {
      expect(handler.processResponse(_row(['abc'])).finished, isFalse);
    });

    test('fails the rows once the response has been read', () async {
      final events = <String>[];
      results.listen((row) => events.add('row ${row[0]}'),
          onError: (Object e) => events.add('error ${e.runtimeType}'),
          onDone: () => events.add('done'));

      handler.processResponse(_row(['1']));
      handler.processResponse(_row(['abc']));
      // The rest of the response is still on the wire and has to be read
      // before the connection can be used again, so nothing ends here.
      expect(handler.processResponse(_row(['2'])).finished, isFalse);
      await pumpEventQueue();
      expect(events, equals(['row 1']));

      expect(handler.processResponse(_eof()).finished, isTrue);
      await pumpEventQueue();
      expect(events, equals(['row 1', 'error FormatException', 'done']));
    });
  });
}
