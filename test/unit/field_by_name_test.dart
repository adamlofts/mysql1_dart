library sqljocky.test.unit.field_by_name_test;

import 'package:sqljocky/constants.dart';
import 'package:sqljocky/src/prepared_statements/binary_data_packet.dart';
import 'package:sqljocky/src/prepared_statements/execute_query_handler.dart';
import 'package:sqljocky/src/query/query_stream_handler.dart';
import 'package:sqljocky/src/query/standard_data_packet.dart';
import 'package:sqljocky/src/results/field_impl.dart';
import 'package:sqljocky/src/results/row.dart';

import 'package:test/test.dart';

void main() {
  group('field by name, standard data packets:', () {
    test('should create field index', () {
      var handler = new QueryStreamHandler("");
      var field = new FieldImpl.forTests(FIELD_TYPE_INT24);
      field.setName("123");
      handler.fieldPackets.add(field);
      var fieldIndex = handler.createFieldIndex();
      expect(fieldIndex, hasLength(0));

      field = new FieldImpl.forTests(FIELD_TYPE_INT24);
      field.setName("_abc");
      handler.fieldPackets.add(field);
      fieldIndex = handler.createFieldIndex();
      expect(fieldIndex, hasLength(0));

      field = new FieldImpl.forTests(FIELD_TYPE_INT24);
      field.setName("abc");
      handler.fieldPackets.add(field);
      fieldIndex = handler.createFieldIndex();
      expect(fieldIndex, hasLength(1));
      expect(fieldIndex.keys, contains(new Symbol("abc")));

      field = new FieldImpl.forTests(FIELD_TYPE_INT24);
      field.setName("a123");
      handler.fieldPackets.clear();
      handler.fieldPackets.add(field);
      fieldIndex = handler.createFieldIndex();
      expect(fieldIndex, hasLength(1));
      expect(fieldIndex.keys, contains(new Symbol("a123")));
    });

    test('should call noSuchMethod', () {
      var fieldIndex = new Map<Symbol, int>();
      fieldIndex[new Symbol("one")] = 0;
      fieldIndex[new Symbol("two")] = 1;
      fieldIndex[new Symbol("three")] = 2;
      var values = [5, "hello", null];

      Row row = new StandardDataPacket.forTests(values, fieldIndex);
      expect(row.one, equals(5));
      expect(row.two, equals("hello"));
      expect(row.three, equals(null));
    });

    test('should fail for non-existent properties', () {
      var fieldIndex = new Map<Symbol, int>();
      var values = [];

      Row row = new StandardDataPacket.forTests(values, fieldIndex);

      expect(() => print(row.one), throwsNoSuchMethodError);
    });
  });

  group('field by name, binary data packets:', () {
    test('should create field index', () {
      var handler = new ExecuteQueryHandler(null, null, null);
      var field = new FieldImpl.forTests(FIELD_TYPE_INT24);
      field.setName("123");
      handler.fieldPackets.add(field);
      var fieldIndex = handler.createFieldIndex();
      expect(fieldIndex, hasLength(0));

      field = new FieldImpl.forTests(FIELD_TYPE_INT24);
      field.setName("_abc");
      handler.fieldPackets.add(field);
      fieldIndex = handler.createFieldIndex();
      expect(fieldIndex, hasLength(0));

      field = new FieldImpl.forTests(FIELD_TYPE_INT24);
      field.setName("abc");
      handler.fieldPackets.add(field);
      fieldIndex = handler.createFieldIndex();
      expect(fieldIndex, hasLength(1));
      expect(fieldIndex.keys, contains(new Symbol("abc")));

      field = new FieldImpl.forTests(FIELD_TYPE_INT24);
      field.setName("a123");
      handler.fieldPackets.clear();
      handler.fieldPackets.add(field);
      fieldIndex = handler.createFieldIndex();
      expect(fieldIndex, hasLength(1));
      expect(fieldIndex.keys, contains(new Symbol("a123")));
    });

    test('should call noSuchMethod', () {
      var fieldIndex = new Map<Symbol, int>();
      fieldIndex[new Symbol("one")] = 0;
      fieldIndex[new Symbol("two")] = 1;
      fieldIndex[new Symbol("three")] = 2;
      var values = [5, "hello", null];

      Row row = new BinaryDataPacket.forTests(values, fieldIndex);
      expect(row.one, equals(5));
      expect(row.two, equals("hello"));
      expect(row.three, equals(null));
    });

    test('should fail for non-existent properties', () {
      var fieldIndex = new Map<Symbol, int>();
      var values = [];

      Row row = new BinaryDataPacket.forTests(values, fieldIndex);

      expect(() => print(row.one), throwsNoSuchMethodError);
    });
  });
}
