part of sqljocky;

void runFieldByNameTests() {
  group('field by name, standard data packets:', () {
    test('should create field index', () {
      var handler = new _QueryStreamHandler("");
      var field = new _FieldImpl._forTests(FIELD_TYPE_INT24);
      field._name = "123";
      handler._fieldPackets.add(field);
      var fieldIndex = handler._createFieldIndex();
      expect(fieldIndex, hasLength(0));

      field = new _FieldImpl._forTests(FIELD_TYPE_INT24);
      field._name = "_abc";
      handler._fieldPackets.add(field);
      fieldIndex = handler._createFieldIndex();
      expect(fieldIndex, hasLength(0));

      field = new _FieldImpl._forTests(FIELD_TYPE_INT24);
      field._name = "abc";
      handler._fieldPackets.add(field);
      fieldIndex = handler._createFieldIndex();
      expect(fieldIndex, hasLength(1));
      expect(fieldIndex.keys, contains(new Symbol("abc")));

      field = new _FieldImpl._forTests(FIELD_TYPE_INT24);
      field._name = "a123";
      handler._fieldPackets.clear();
      handler._fieldPackets.add(field);
      fieldIndex = handler._createFieldIndex();
      expect(fieldIndex, hasLength(1));
      expect(fieldIndex.keys, contains(new Symbol("a123")));
    });

    test('should call noSuchMethod', () {
      var fieldIndex = new Map<Symbol, int>();
      fieldIndex[new Symbol("one")] = 0;
      fieldIndex[new Symbol("two")] = 1;
      fieldIndex[new Symbol("three")] = 2;
      var values = [5, "hello", null];

      Row row = new _StandardDataPacket._forTests(values, fieldIndex);
      expect(row.one, equals(5));
      expect(row.two, equals("hello"));
      expect(row.three, equals(null));
    });

    test('should fail for non-existent properties', () {
      var fieldIndex = new Map<Symbol, int>();
      var values = [];

      Row row = new _StandardDataPacket._forTests(values, fieldIndex);
      try {
        var x = row.one;
        expect(true, isFalse);
      } on NoSuchMethodError {
        expect(true, isTrue);
      }
    });
  });

  group('field by name, binary data packets:', () {
    test('should create field index', () {
      var handler = new _ExecuteQueryHandler(null, null, null);
      var field = new _FieldImpl._forTests(FIELD_TYPE_INT24);
      field._name = "123";
      handler._fieldPackets.add(field);
      var fieldIndex = handler._createFieldIndex();
      expect(fieldIndex, hasLength(0));

      field = new _FieldImpl._forTests(FIELD_TYPE_INT24);
      field._name = "_abc";
      handler._fieldPackets.add(field);
      fieldIndex = handler._createFieldIndex();
      expect(fieldIndex, hasLength(0));

      field = new _FieldImpl._forTests(FIELD_TYPE_INT24);
      field._name = "abc";
      handler._fieldPackets.add(field);
      fieldIndex = handler._createFieldIndex();
      expect(fieldIndex, hasLength(1));
      expect(fieldIndex.keys, contains(new Symbol("abc")));

      field = new _FieldImpl._forTests(FIELD_TYPE_INT24);
      field._name = "a123";
      handler._fieldPackets.clear();
      handler._fieldPackets.add(field);
      fieldIndex = handler._createFieldIndex();
      expect(fieldIndex, hasLength(1));
      expect(fieldIndex.keys, contains(new Symbol("a123")));
    });

    test('should call noSuchMethod', () {
      var fieldIndex = new Map<Symbol, int>();
      fieldIndex[new Symbol("one")] = 0;
      fieldIndex[new Symbol("two")] = 1;
      fieldIndex[new Symbol("three")] = 2;
      var values = [5, "hello", null];

      Row row = new _BinaryDataPacket._forTests(values, fieldIndex);
      expect(row.one, equals(5));
      expect(row.two, equals("hello"));
      expect(row.three, equals(null));
    });

    test('should fail for non-existent properties', () {
      var fieldIndex = new Map<Symbol, int>();
      var values = [];

      Row row = new _BinaryDataPacket._forTests(values, fieldIndex);
      try {
        var x = row.one;
        expect(true, isFalse);
      } on NoSuchMethodError {
        expect(true, isTrue);
      }
    });
  });
}
