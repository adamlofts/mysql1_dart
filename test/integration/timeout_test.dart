library mysql1.test.timeout_test;

import 'dart:async';

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

// A query which times out is still running on the server, and its response
// will arrive whenever it does. The connection cannot be used for anything
// else without that response being taken for the answer, so it is closed.
void main() {
  test('a query which times out closes the connection', () async {
    final settings = ConnectionSettings.copy(testConnectionSettings())
      ..timeout = const Duration(milliseconds: 500);
    final conn = await connectForTest(settings);
    addTearDown(conn.close);

    expect((await conn.query('select 1 as n')).single['n'], equals(1));
    await expectLater(
        conn.query('select sleep(3)'), throwsA(isA<TimeoutException>()));
    await expectLater(conn.query('select 1 as n'), throwsA(isA<StateError>()));
  });

  test('queries queued behind one which times out fail', () async {
    final settings = ConnectionSettings.copy(testConnectionSettings())
      ..timeout = const Duration(milliseconds: 500);
    final conn = await connectForTest(settings);
    addTearDown(conn.close);

    final slow = conn.query('select sleep(3)');
    final queued = conn.query('select 1 as n');
    await expectLater(slow, throwsA(isA<TimeoutException>()));
    await expectLater(queued, throwsA(isA<StateError>()));
  });
}
