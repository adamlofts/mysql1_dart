library mysql1.test.no_tls_test;

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

// This needs a server which has TLS turned off, which is not the one the
// rest of the suite runs against: MYSQL_NO_TLS_PORT says where it is.
void main() {
  final port = testNoTlsPort();

  // The greeting which says whether the server can do TLS is sent in the
  // clear. Going ahead without TLS because it says not would let anyone
  // between the client and the server turn it off.
  test('a server without TLS is not connected to when TLS is asked for',
      () async {
    final settings = ConnectionSettings(
        host: testConnectionSettings().host,
        port: port!,
        user: 'root',
        password: 'not sent',
        useSSL: true);
    await expectLater(
        MySqlConnection.connect(settings),
        throwsA(isA<MySqlClientError>()
            .having((e) => e.message, 'message', contains('TLS'))));
  }, skip: port == null ? 'MYSQL_NO_TLS_PORT is not set' : null);
}
