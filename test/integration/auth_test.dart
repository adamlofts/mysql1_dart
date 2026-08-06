library mysql1.test.auth_test;

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
    final connection = await MySqlConnection.connect(settingsFor(nativeUser));
    addTearDown(connection.close);

    final results = await connection.query('select 1 + ? as answer', [41]);
    expect(results.first.first, equals(42));
  });

  test('reports what to do when the server wants full authentication',
      () async {
    if (!await pluginAvailable('caching_sha2_password')) {
      markTestSkipped('this server has no caching_sha2_password plugin');
      return;
    }
    await createUser(sha2User, 'caching_sha2_password');

    // The server has not cached this brand new account's password, so it asks
    // for full authentication. Over a connection a third party could read,
    // that needs the password RSA encrypted with the server's public key,
    // which this driver cannot do - so it says so rather than carrying on out
    // of step with the server. Change this test if that ever gains RSA.
    await expectLater(
        MySqlConnection.connect(settingsFor(sha2User)),
        throwsA(isA<MySqlClientError>().having(
            (e) => e.message, 'message', contains('full authentication'))));
  });

  test('rejects a wrong password cleanly', () async {
    if (!await pluginAvailable('mysql_native_password')) {
      markTestSkipped('this server has no mysql_native_password plugin');
      return;
    }
    await createUser(nativeUser, 'mysql_native_password');

    // Any error the server itself reports will do. The point is that a bad
    // password comes back as one, rather than as a hang or a connection which
    // then answers every query one packet behind. The exact code is not
    // pinned: which one the server picks depends on how it resolves the
    // client's host.
    final settings = settingsFor(nativeUser)..password = 'not the password';
    await expectLater(
        MySqlConnection.connect(settings), throwsA(isA<MySqlException>()));
  });
}
