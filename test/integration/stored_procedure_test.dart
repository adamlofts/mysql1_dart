library mysql1.test.stored_procedure_test;

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

const tableName = 'sp';

// https://github.com/adamlofts/mysql1_dart/issues/113
//
// The response to CALL is every result set the procedure selects, followed by
// an ok packet for the call itself. All of it has to be read before the next
// query is sent, or that query is answered with what was left behind.
void main() {
  initializeTest(tableName, 'create table $tableName (n int)',
      'insert into $tableName (n) values (1), (2)');

  Future<void> createProcedure(String name, String params, String body) async {
    await conn.query('drop procedure if exists $name');
    await conn.query('create procedure $name($params) begin $body end');
  }

  test('each call gets its own result', () async {
    await createProcedure('sp_echo', 'x int', 'select x as answer;');
    for (var i = 1; i <= 3; i++) {
      var results = await conn.query('call sp_echo(?)', [i]);
      expect(results.single['answer'], equals(i));
    }
    var results = await conn.query('select 99 as answer');
    expect(results.single['answer'], equals(99));
  });

  test('a procedure with several result sets returns the first', () async {
    await createProcedure('sp_two', '',
        'select n from $tableName order by n; select 10 as a, 20 as b;');
    for (var i = 0; i < 2; i++) {
      var results = await conn.query('call sp_two()');
      expect(results.map((r) => r['n']), equals([1, 2]));
      expect(results.fields.map((f) => f.name), equals(['n']));
    }
    var results = await conn.query('select 99 as answer');
    expect(results.single['answer'], equals(99));
  });

  test('a procedure with no result set', () async {
    await createProcedure(
        'sp_insert', 'x int', 'insert into $tableName (n) values (x);');
    var results = await conn.query('call sp_insert(3)');
    expect(results, isEmpty);
    expect(results.affectedRows, equals(1));
    results = await conn.query('select count(*) as answer from $tableName');
    expect(results.single['answer'], equals(3));
  });

  test('a procedure which fails after a result set', () async {
    await createProcedure(
        'sp_fail', '', 'select 1 as answer; select * from sp_no_such_table;');
    await expectLater(
        conn.query('call sp_fail()'),
        throwsA(isA<MySqlException>()
            .having((e) => e.errorNumber, 'errorNumber', 1146)));
    var results = await conn.query('select 99 as answer');
    expect(results.single['answer'], equals(99));
  });
}
