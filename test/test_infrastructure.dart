library mysql1.test.test_infrastructure;

import 'dart:io';

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import 'test_util.dart';

MySqlConnection get conn => _conn;
late MySqlConnection _conn;

/// The `key=value` pairs in `connection.options`, ignoring blank lines and
/// `#` comments. Missing file means no pairs, which is fine - everything it
/// can set has either a default or an environment variable.
Map<String, String> _readOptionsFile() {
  final file = File('connection.options');
  if (!file.existsSync()) {
    return {};
  }

  final options = <String, String>{};
  for (var line in file.readAsLinesSync()) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final separator = line.indexOf('=');
    if (separator == -1) {
      continue;
    }
    options[line.substring(0, separator).trim()] =
        line.substring(separator + 1).trim();
  }
  return options;
}

/// One setting, from the environment if it is there and not empty, otherwise
/// from `connection.options`.
///
/// An empty environment variable counts as unset. A CI matrix has no way to
/// leave one out, and an empty password is not the same as no password: the
/// driver sends an empty auth response for null, and a hash of '' otherwise.
String? _option(String key, String envKey) {
  final fromEnv = Platform.environment[envKey];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  return _readOptionsFile()[key];
}

/// The unix socket to run against, if the tests are not using TCP.
///
/// Worth having because the server only asks for - and only accepts - a
/// cleartext password over a connection nobody else can read, so this is the
/// only way to exercise caching_sha2_password full authentication without
/// implementing the RSA alternative.
String? testSocketPath() => _option('socket', 'MYSQL_SOCKET');

/// The certificate to trust when the tests connect over TLS, if they do.
///
/// Setting it is what turns TLS on. It is the server's own certificate or the
/// authority which signed it, and the server has to be reached by a name or
/// address the certificate is for.
String? testTlsCertificate() => _option('ssl_ca', 'MYSQL_SSL_CA');

/// The port of a second server which has TLS turned off, if there is one.
/// It is on the same host as the first, and only has to answer: nothing logs
/// in to it.
int? testNoTlsPort() {
  final port = _option('no_tls_port', 'MYSQL_NO_TLS_PORT');
  return port == null ? null : int.parse(port);
}

/// Whether nobody else can read the connection the tests use, which decides
/// whether the server can be sent a password in the clear.
bool testConnectionIsPrivate() =>
    testSocketPath() != null || testTlsCertificate() != null;

/// How the integration tests reach the database.
///
/// `connection.options` is read first, then any `MYSQL_*` environment
/// variable overrides it, so a checkout can be pointed at another server
/// without editing a tracked file.
ConnectionSettings testConnectionSettings() {
  final socket = testSocketPath();
  if (socket != null) {
    return ConnectionSettings.socket(
      path: socket,
      user: _option('user', 'MYSQL_USER'),
      password: _option('password', 'MYSQL_PASSWORD'),
      db: _option('db', 'MYSQL_DATABASE'),
    );
  }

  final port = _option('port', 'MYSQL_PORT');
  final certificate = testTlsCertificate();

  return ConnectionSettings(
    useSSL: certificate != null,
    securityContext: certificate == null
        ? null
        : (SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificates(certificate)),
    user: _option('user', 'MYSQL_USER'),
    password: _option('password', 'MYSQL_PASSWORD'),
    port: port == null ? 3306 : int.parse(port),
    db: _option('db', 'MYSQL_DATABASE'),
    host: _option('host', 'MYSQL_HOST') ?? 'localhost',
  );
}

/// Connect for a test, telling the driver when the settings are a unix
/// socket. It cannot tell on its own - the path is carried in `host`.
Future<MySqlConnection> connectForTest(ConnectionSettings settings) =>
    MySqlConnection.connect(settings, isUnixSocket: testSocketPath() != null);

void initializeTest([String? tableName, String? createSql, String? insertSql]) {
  var s = testConnectionSettings();

  setUp(() async {
    // Ensure db exists
    var checkSettings = ConnectionSettings.copy(s);
    checkSettings.db = null;
    final c = await connectForTest(checkSettings);
    await c.query('CREATE DATABASE IF NOT EXISTS ${s.db} CHARACTER SET utf8');
    await c.close();

    _conn = await connectForTest(s);

    if (tableName != null) {
      await setup(_conn, tableName, createSql, insertSql);
    }
  });

  tearDown(() async {
    await _conn.close();
  });
}
