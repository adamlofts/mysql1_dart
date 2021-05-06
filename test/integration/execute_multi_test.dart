library mysql1.test.blob_test;

import 'package:test/test.dart';

import '../test_infrastructure.dart';

void main() {
  initializeTest('stream', 'create table stream (id integer, name text)',
      "insert into stream (id, name) values (1, 'A'), (2, 'B'), (3, 'C')");

  test('store data', () async {
    var values = await conn.queryMulti('select * from stream where id = ?', [
      [1],
      [2],
      [3]
    ]);
    expect(values, hasLength(3));

    var resultList = values[0].toList();
    expect(resultList[0][0], equals(1));
    expect(resultList[0][1].toString(), equals('A'));

    resultList = values[1].toList();
    expect(resultList[0][0], equals(2));
    expect(resultList[0][1].toString(), equals('B'));

    resultList = values[2].toList();
    expect(resultList[0][0], equals(3));
    expect(resultList[0][1].toString(), equals('C'));
  });

  test('issue 43', () async {
    await conn.transaction((context) async {
      await context.query('SELECT * FROM stream');
      context.rollback();
    });
  });

  test('transaction rollback', () async {
    var count = await conn.query('SELECT COUNT(*) FROM stream');
    expect(count.first.first, 3);

    await conn.transaction((context) async {
      await context.query(
          "insert into stream (id, name) values (1, 'A'), (2, 'B'), (3, 'C')");
      context.rollback();
    });

    count = await conn.query('SELECT COUNT(*) FROM stream');
    expect(count.first.first, 3);
  });

  test('transaction commit', () async {
    var count = await conn.query('SELECT COUNT(*) FROM stream');
    expect(count.first.first, 3);

    await conn.transaction((context) async {
      await context.query(
          "insert into stream (id, name) values (1, 'A'), (2, 'B'), (3, 'C')");
    });

    count = await conn.query('SELECT COUNT(*) FROM stream');
    expect(count.first.first, 6);
  });
}
