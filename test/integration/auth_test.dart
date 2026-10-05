library mysql1.test.auth_test;

import 'dart:io';

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

const nativeUser = 'mysql1_native';
const sha2User = 'mysql1_sha2';
const userPassword = 'secret';

/// Whether the server has [name] loaded. Neither plugin is available
/// everywhere: 5.7 has no caching_sha2_password, and 8.4 removed
/// mysql_native_password.
Future<bool> pluginAvailable(String name) async {
  final results = await conn.query(
      'select plugin_status from information_schema.plugins '
      'where plugin_name = ?',
      [name]);
  return results.isNotEmpty &&
      results.first.first.toString().toUpperCase() == 'ACTIVE';
}

Future<void> createUser(String user, String plugin) async {
  final db = testConnectionSettings().db;
  await conn.query("drop user if exists '$user'@'%'");
  await conn.query(
      "create user '$user'@'%' identified with $plugin by '$userPassword'");
  await conn.query("grant all on `$db`.* to '$user'@'%'");
}

ConnectionSettings settingsFor(String user) =>
    ConnectionSettings.copy(testConnectionSettings())
      ..user = user
      ..password = userPassword;

void main() {
  initializeTest();

  tearDown(() async {
    await conn.query("drop user if exists '$nativeUser'@'%'");
    await conn.query("drop user if exists '$sha2User'@'%'");
  });

  test('connects to an account whose plugin is not the server default',
      () async {
    if (!await pluginAvailable('mysql_native_password')) {
      markTestSkipped('this server has no mysql_native_password plugin');
      return;
    }
    await createUser(nativeUser, 'mysql_native_password');

    // On a server whose default is caching_sha2_password this is an auth
    // switch request: the handshake names one plugin and the account uses
    // another, so the server sends a new plugin name and scramble which the
    // client has to answer. It is the shape managed MySQL usually has.
    final connection = await connectForTest(settingsFor(nativeUser));
    addTearDown(connection.close);

    final results = await connection.query('select 1 + ? as answer', [41]);
    expect(results.first.first, equals(42));
  });

  test('authenticates an account the server has not cached', () async {
    if (!await pluginAvailable('caching_sha2_password')) {
      markTestSkipped('this server has no caching_sha2_password plugin');
      return;
    }
    await createUser(sha2User, 'caching_sha2_password');

    // Nothing is cached for a brand new account, so the server asks for full
    // authentication: the password itself rather than a hash of it.
    if (!testConnectionIsPrivate()) {
      // Over plain TCP that means encrypting it with the server's public key,
      // which needs RSA this driver does not have. Say so, rather than
      // carrying on out of step with the server. Change this when it gains
      // RSA.
      await expectLater(
          connectForTest(settingsFor(sha2User)),
          throwsA(isA<MySqlClientError>().having(
              (e) => e.message, 'message', contains('full authentication'))));
      return;
    }

    // Over a unix socket or TLS nobody can read the connection, so the
    // password goes in the clear and authentication completes.
    final first = await connectForTest(settingsFor(sha2User));
    expect((await first.query('select 1 + ? as answer', [41])).first.first,
        equals(42));
    await first.close();

    // The server caches the password when full authentication succeeds, so
    // the next connection gets fast auth success followed by an ok packet -
    // the exchange that used to end the handshake early and leave every
    // query on the connection reading the previous response.
    final second = await connectForTest(settingsFor(sha2User));
    expect((await second.query('select 1 + ? as answer', [41])).first.first,
        equals(42));
    await second.close();
  });

  test('rejects a wrong password cleanly', () async {
    if (!await pluginAvailable('mysql_native_password')) {
      markTestSkipped('this server has no mysql_native_password plugin');
      return;
    }
    await createUser(nativeUser, 'mysql_native_password');

    // The point is that a bad password fails, rather than hanging or handing
    // back a connection which answers every query one packet behind.
    //
    // Which failure depends on the transport. Over TCP the server's error
    // packet is read and reported. Over a unix socket the server closes the
    // connection in the same breath and the driver reports the close: the
    // error packet is there - the official client prints it - but the pending
    // read loses the race with the close event. Worth fixing in the socket
    // layer, and nothing to do with authentication.
    final settings = settingsFor(nativeUser)..password = 'not the password';
    await expectLater(connectForTest(settings),
        throwsA(anyOf(isA<MySqlException>(), isA<SocketException>())));
  });
}
