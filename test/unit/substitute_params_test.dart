library mysql1.substitute_params_test;

import 'package:mysql1/mysql1.dart';
import 'package:mysql1/src/substitute_params.dart';

import 'package:test/test.dart';

void main() {
  group('substituteParams:', () {
    test('leaves a statement with no placeholders alone', () {
      expect(substituteParams('select 1', []), equals('select 1'));
    });

    test('substitutes in order', () {
      expect(
          substituteParams(
              'select * from t where a = ? and b = ? and c = ?', [1, 'two', 3]),
          equals("select * from t where a = 1 and b = 'two' and c = 3"));
    });

    test('does not substitute a ? in a string literal', () {
      expect(substituteParams("select '?' where a = ?", [1]),
          equals("select '?' where a = 1"));
      expect(substituteParams('select "?" where a = ?', [1]),
          equals('select "?" where a = 1'));
    });

    test('does not substitute a ? in a quoted identifier', () {
      expect(substituteParams('select `a?b` from t where c = ?', [1]),
          equals('select `a?b` from t where c = 1'));
    });

    test('understands a doubled quote inside a literal', () {
      expect(substituteParams("select 'it''s ?' where a = ?", [1]),
          equals("select 'it''s ?' where a = 1"));
    });

    test('understands a backslash escaped quote inside a literal', () {
      expect(substituteParams("select 'it\\'s ?' where a = ?", [1]),
          equals("select 'it\\'s ?' where a = 1"));
    });

    test('a backtick identifier has no backslash escapes', () {
      expect(substituteParams('select `a\\` from t where c = ?', [1]),
          equals('select `a\\` from t where c = 1'));
    });

    test('throws if there are too few values', () {
      expect(
          () => substituteParams('insert into p1 (a, b) values (?, ?)', [1]),
          throwsA(isA<MySqlClientError>().having((e) => e.message, 'message',
              'Length of parameters (1) does not match parameter count in query (2)')));
    });

    test('throws if there are too many values', () {
      expect(
          () => substituteParams('insert into p1 (a) values (?)', [1, 2]),
          throwsA(isA<MySqlClientError>().having((e) => e.message, 'message',
              'Length of parameters (2) does not match parameter count in query (1)')));
    });
  });

  group('sqlLiteral:', () {
    test('null', () {
      expect(sqlLiteral(null), equals('NULL'));
    });

    test('int', () {
      expect(sqlLiteral(0), equals('0'));
      expect(sqlLiteral(-1), equals('-1'));
      expect(sqlLiteral(9007199254740993), equals('9007199254740993'));
    });

    test('double', () {
      expect(sqlLiteral(123.456), equals('123.456'));
      expect(sqlLiteral(-0.5), equals('-0.5'));
    });

    test('double which mysql cannot represent throws', () {
      expect(
          () => sqlLiteral(double.infinity), throwsA(isA<MySqlClientError>()));
      expect(() => sqlLiteral(double.nan), throwsA(isA<MySqlClientError>()));
    });

    test('bool', () {
      expect(sqlLiteral(true), equals('1'));
      expect(sqlLiteral(false), equals('0'));
    });

    test('string', () {
      expect(sqlLiteral('hello'), equals("'hello'"));
      expect(sqlLiteral(''), equals("''"));
    });

    test('string quotes are doubled', () {
      expect(sqlLiteral("it's"), equals("'it''s'"));
    });

    test('string backslashes are doubled', () {
      expect(sqlLiteral(r'a\b'), equals(r"'a\\b'"));
    });

    test('a backslash before a quote does not escape it', () {
      // 'a\'' would end the literal at the doubled quote if the backslash
      // were left alone.
      expect(sqlLiteral("a\\'"), equals(r"'a\\'''"));
    });

    test('string nulls are escaped', () {
      expect(sqlLiteral('a\u0000b'), equals(r"'a\0b'"));
    });

    test('utf8mb4 is passed through', () {
      expect(sqlLiteral('テスト 💯'), equals("'テスト 💯'"));
    });

    test('a value which is not a known type is stringified', () {
      expect(sqlLiteral(Duration(seconds: 1)), equals("'0:00:01.000000'"));
    });

    test('DateTime', () {
      expect(sqlLiteral(DateTime.utc(2018, 1, 2, 3, 4, 5)),
          equals("'2018-01-02 03:04:05'"));
    });

    test('DateTime is written with its fractional seconds', () {
      expect(sqlLiteral(DateTime.utc(2018, 1, 2, 3, 4, 5, 678)),
          equals("'2018-01-02 03:04:05.678000'"));
      expect(sqlLiteral(DateTime.utc(2018, 1, 2, 3, 4, 5, 0, 9)),
          equals("'2018-01-02 03:04:05.000009'"));
    });

    test('DateTime must be in UTC', () {
      expect(() => sqlLiteral(DateTime(2018, 1, 2, 3, 4, 5)),
          throwsA(isA<MySqlClientError>()));
    });

    test('bytes become a hex literal', () {
      expect(sqlLiteral([65, 66, 67, 68]), equals("X'41424344'"));
      expect(
          sqlLiteral(Blob.fromBytes([65, 66, 67, 68])), equals("X'41424344'"));
    });

    test('bytes which are not valid utf8 become a hex literal', () {
      expect(sqlLiteral([0xc3, 0x28]), equals("X'c328'"));
    });

    test('empty bytes become an empty string', () {
      // X'' is not valid syntax.
      expect(sqlLiteral(<int>[]), equals("''"));
      expect(sqlLiteral(Blob.fromBytes([])), equals("''"));
    });

    test('a list which is not bytes throws', () {
      expect(() => sqlLiteral([256]), throwsA(isA<MySqlClientError>()));
      expect(() => sqlLiteral([-1]), throwsA(isA<MySqlClientError>()));
    });
  });
}
