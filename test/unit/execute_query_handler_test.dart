part of sqljocky;

void runExecuteQueryHandlerTests() {
  group('ExecuteQueryHandler._createNullMap', () {
    test('can build empty map', () {
      var handler = new _ExecuteQueryHandler(null, false, []);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([]));
    });

    test('can build map with no nulls', () {
      var handler = new _ExecuteQueryHandler(null, false, [1]);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([0]));
    });

    test('can build map with one null', () {
      var handler = new _ExecuteQueryHandler(null, false, [null]);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([1]));
    });

    test('can build map with eight nulls', () {
      var handler = new _ExecuteQueryHandler(null, false, [null, null, null, null, null, null, null, null]);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([255]));
    });

    test('can build map with eight not nulls', () {
      var handler = new _ExecuteQueryHandler(null, false, [0, 0, 0, 0, 0, 0, 0, 0]);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([0]));
    });

    test('can build map with some nulls and some not', () {
      var handler = new _ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null]);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([129]));
    });

    test('can build map with some nulls and some not', () {
      var handler = new _ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null]);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([129]));
    });

    test('can build map which is more than one byte', () {
      var handler = new _ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null, 0, 0, 0, 0, 0, 0, 0, 0]);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([129, 0]));
    });

    test('can build map which just is more than one byte', () {
      var handler = new _ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null, 0]);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([129, 0]));
    });

    test('can build map which just is more than one byte with a null', () {
      var handler = new _ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null, null]);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([129, 1]));
    });

    test('can build map which just is more than one byte with a null, another pattern', () {
      var handler = new _ExecuteQueryHandler(null, false, [null, 0, null, 0, 0, 0, 0, null, null]);
      var nullmap = handler._createNullMap();
      expect(nullmap, equals([129 + 4, 1]));
    });
  });

  group('ExecuteQueryHandler._writeValuesToBuffer', () {
    var types;
    var values;

    setUp(() {
      types = <int>[];
      values = new ListWriter(<int>[]);
    });

    test('can write values for unexecuted query', () {
      var preparedQuery = new MockPreparedQuery();
      preparedQuery.when(callsTo('get statementHandlerId')).alwaysReturn(123);

      var handler = new _ExecuteQueryHandler(preparedQuery, false, []);
      var buffer = handler._writeValuesToBuffer([], values, types);
      expect(buffer.length, equals(11));
      expect(buffer.list, equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 1]));
    });

    test('can write values for executed query', () {
      var preparedQuery = new MockPreparedQuery();
      preparedQuery.when(callsTo('get statementHandlerId')).alwaysReturn(123);

      var handler = new _ExecuteQueryHandler(preparedQuery, true, []);
      var buffer = handler._writeValuesToBuffer([], values, types);
      expect(buffer.length, equals(11));
      expect(buffer.list, equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 0]));
    });

    test('can write values for executed query with nullmap', () {
      var preparedQuery = new MockPreparedQuery();
      preparedQuery.when(callsTo('get statementHandlerId')).alwaysReturn(123);

      var handler = new _ExecuteQueryHandler(preparedQuery, true, []);
      var buffer = handler._writeValuesToBuffer([5, 6, 7], values, types);
      expect(buffer.length, equals(14));
      expect(buffer.list, equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 5, 6, 7, 0]));
    });

    test('can write values for unexecuted query with values', () {
      var preparedQuery = new MockPreparedQuery();
      preparedQuery.when(callsTo('get statementHandlerId')).alwaysReturn(123);

      types = [100, 150, 200];
      values.add(50);
      values.add(60);
      values.add(70);
      var handler = new _ExecuteQueryHandler(preparedQuery, false, []);
      var buffer = handler._writeValuesToBuffer([5, 6, 7], values, types);
      expect(buffer.length, equals(20));
      expect(buffer.list, equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 5, 6, 7, 1, 100, 150, 200, 50, 60, 70]));
    });

    test('can write values for unexecuted query with more values', () {
      var preparedQuery = new MockPreparedQuery();
      preparedQuery.when(callsTo('get statementHandlerId')).alwaysReturn(123);

      types = [100, 101, 102, 103, 104, 105];
      values.add(50);
      values.add(51);
      values.add(52);
      values.add(53);
      values.add(54);
      values.add(55);
      values.add(56);
      var handler = new _ExecuteQueryHandler(preparedQuery, false, []);
      var buffer = handler._writeValuesToBuffer([5, 6, 7], values, types);
      expect(buffer.length, equals(27));
      expect(buffer.list, equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 5, 6, 7, 1, 100, 101, 102, 103, 104, 105, 50, 51, 52, 53, 54, 55, 56]));
    });
  });
}

class MockPreparedQuery extends Mock implements _PreparedQuery {}
