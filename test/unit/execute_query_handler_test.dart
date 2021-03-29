// ignore_for_file: strong_mode_implicit_dynamic_list_literal

library mysql1.test.unit.execute_query_handler_test;

import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:mysql1/src/blob.dart';
import 'package:mysql1/src/prepared_statements/execute_query_handler.dart';

import 'package:mysql1/src/prepared_statements/prepared_query.dart';

import 'package:test/test.dart';

class MockPreparedQuery extends Mock implements PreparedQuery {}

void main() {
  group('ExecuteQueryHandler.createNullMap', () {
    test('can build empty map', () {
      var handler = ExecuteQueryHandler(null, false, []);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([]));
    });

    test('can build map with no nulls', () {
      var handler = ExecuteQueryHandler(null, false, [1]);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([0]));
    });

    test('can build map with one null', () {
      var handler = ExecuteQueryHandler(null, false, [null]);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([1]));
    });

    test('can build map with eight nulls', () {
      var handler = ExecuteQueryHandler(
          null, false, [null, null, null, null, null, null, null, null]);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([255]));
    });

    test('can build map with eight not nulls', () {
      var handler = ExecuteQueryHandler(null, false, [0, 0, 0, 0, 0, 0, 0, 0]);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([0]));
    });

    test('can build map with some nulls and some not', () {
      var handler =
          ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null]);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([129]));
    });

    test('can build map with some nulls and some not', () {
      var handler =
          ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null]);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([129]));
    });

    test('can build map which is more than one byte', () {
      var handler = ExecuteQueryHandler(
          null, false, [null, 0, 0, 0, 0, 0, 0, null, 0, 0, 0, 0, 0, 0, 0, 0]);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([129, 0]));
    });

    test('can build map which just is more than one byte', () {
      var handler =
          ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null, 0]);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([129, 0]));
    });

    test('can build map which just is more than one byte with a null', () {
      var handler = ExecuteQueryHandler(
          null, false, [null, 0, 0, 0, 0, 0, 0, null, null]);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([129, 1]));
    });

    test(
        'can build map which just is more than one byte with a null, another pattern',
        () {
      var handler = ExecuteQueryHandler(
          null, false, [null, 0, null, 0, 0, 0, 0, null, null]);
      var nullmap = handler.createNullMap();
      expect(nullmap, equals([129 + 4, 1]));
    });
  });

  group('ExecuteQueryHandler.writeValuesToBuffer', () {
    late List<int> types;

    setUp(() {
      types = <int>[];
    });

    test('can write values for unexecuted query', () {
      var preparedQuery = MockPreparedQuery();
      when(() => preparedQuery.statementHandlerId).thenReturn(123);

      var handler = ExecuteQueryHandler(preparedQuery, false, []);
      handler.preparedValues = [];
      var buffer = handler.writeValuesToBuffer([], 0, types);
      expect(buffer.length, equals(11));
      expect(buffer.list, equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 1]));
    });

    test('can write values for executed query', () {
      var preparedQuery = MockPreparedQuery();
      when(() => preparedQuery.statementHandlerId).thenReturn(123);

      var handler = ExecuteQueryHandler(preparedQuery, true, []);
      handler.preparedValues = [];
      var buffer = handler.writeValuesToBuffer([], 0, types);
      expect(buffer.length, equals(11));
      expect(buffer.list, equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 0]));
    });

    test('can write values for executed query with nullmap', () {
      var preparedQuery = MockPreparedQuery();
      when(() => preparedQuery.statementHandlerId).thenReturn(123);

      var handler = ExecuteQueryHandler(preparedQuery, true, []);
      handler.preparedValues = [];
      var buffer = handler.writeValuesToBuffer([5, 6, 7], 0, types);
      expect(buffer.length, equals(14));
      expect(
          buffer.list, equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 5, 6, 7, 0]));
    });

    test('can write values for unexecuted query with values', () {
      var preparedQuery = MockPreparedQuery();
      when(() => preparedQuery.statementHandlerId).thenReturn(123);

      types = [100];
      var handler = ExecuteQueryHandler(preparedQuery, false, [123]);
      handler.preparedValues = [123];
      var buffer = handler.writeValuesToBuffer([5, 6, 7], 8, types);
      expect(buffer.length, equals(23));
      expect(
          buffer.list,
          equals([
            23,
            123,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            5,
            6,
            7,
            1,
            100,
            123,
            0,
            0,
            0,
            0,
            0,
            0,
            0
          ]));
    });
  });

  group('ExecuteQueryHandler.prepareValue', () {
    MockPreparedQuery preparedQuery;
    late ExecuteQueryHandler handler;

    setUp(() {
      preparedQuery = MockPreparedQuery();
      handler = ExecuteQueryHandler(preparedQuery, false, []);
    });

    test('can prepare int values correctly', () {
      expect(handler.prepareValue(123), equals(123));
    });

    test('can prepare string values correctly', () {
      expect(handler.prepareValue('hello'), equals(utf8.encode('hello')));
    });

    test('can prepare double values correctly', () {
      expect(handler.prepareValue(123.45), equals(utf8.encode('123.45')));
    });

    test('can prepare datetime values correctly', () {
      var dateTime = DateTime.utc(2014, 3, 4, 5, 6, 7, 8);
      expect(handler.prepareValue(dateTime), equals(dateTime));
    });

    test('can prepare bool values correctly', () {
      expect(handler.prepareValue(true), equals(true));
    });

    test('can prepare list values correctly', () {
      expect(handler.prepareValue([1, 2, 3]), equals([1, 2, 3]));
    });

    test('can prepare blob values correctly', () {
      expect(handler.prepareValue(Blob.fromString('hello')),
          equals(utf8.encode('hello')));
    });
  });

  group('ExecuteQueryHandler._measureValue', () {
    MockPreparedQuery preparedQuery;
    late ExecuteQueryHandler handler;

    setUp(() {
      preparedQuery = MockPreparedQuery();
      handler = ExecuteQueryHandler(preparedQuery, false, []);
    });

    test('can measure int values correctly', () {
      expect(handler.measureValue(123, 123), equals(8));
    });

    test('can measure short string correctly', () {
      var string = 'a';
      var preparedString = utf8.encode(string);
      expect(handler.measureValue(string, preparedString), equals(2));
    });

    test('can measure longer string correctly', () {
      var string = String.fromCharCodes(List.filled(300, 65));
      var preparedString = utf8.encode(string);
      expect(handler.measureValue(string, preparedString),
          equals(3 + string.length));
    });

    test('can measure even longer string correctly', () {
      var string = String.fromCharCodes(List.filled(70000, 65));
      var preparedString = utf8.encode(string);
      expect(handler.measureValue(string, preparedString),
          equals(4 + string.length));
    });

//    test('can measure even very long string correctly', () {
//      var string = String.fromCharCodes(List.filled(2 << 23 + 1, 65));
//      var preparedString = utf8.encode(string);
//      expect(handler.measureValue(string, preparedString),
//          equals(5 + string.length));
//    });

    //etc
  });
}

/*class MockPreparedQuery extends Mock implements PreparedQuery {}*/
