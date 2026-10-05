library mysql1.test.tls_test;

import 'dart:io';

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

// These need a server reached over TLS, which is what setting MYSQL_SSL_CA
// says the tests have. The rest of the suite runs over it too, when it is
// set; these are about the TLS itself.
void main() {
  if (testTlsCertificate() == null) {
    test('TLS', () {}, skip: 'MYSQL_SSL_CA is not set');
    return;
  }

  initializeTest();

  test('the connection is encrypted', () async {
    final results = await conn.query("show status like 'Ssl_cipher'");
    expect(results.single[1].toString(), isNotEmpty);
  });

  test('a certificate which is not trusted fails the connection', () async {
    final settings = ConnectionSettings.copy(testConnectionSettings())
      ..securityContext = SecurityContext(withTrustedRoots: false);
    await expectLater(
        connectForTest(settings), throwsA(isA<HandshakeException>()));
  });

  test('onBadCertificate can accept what would be refused', () async {
    final asked = <X509Certificate>[];
    final settings = ConnectionSettings.copy(testConnectionSettings())
      ..securityContext = SecurityContext(withTrustedRoots: false)
      ..onBadCertificate = (certificate) {
        asked.add(certificate);
        return true;
      };
    final connection = await connectForTest(settings);
    addTearDown(connection.close);
    expect(asked, isNotEmpty);
    expect((await connection.query('select 1 as n')).single['n'], equals(1));
  });

  test('a server which requires TLS refuses a connection without it', () async {
    final required = await conn.query('select @@require_secure_transport');
    if (required.single[0] != 1) {
      markTestSkipped('this server does not require TLS');
      return;
    }
    final settings = ConnectionSettings.copy(testConnectionSettings())
      ..useSSL = false;
    // ER_SECURE_TRANSPORT_REQUIRED
    await expectLater(
        connectForTest(settings),
        throwsA(isA<MySqlException>()
            .having((e) => e.errorNumber, 'errorNumber', 3159)));
  });
}
