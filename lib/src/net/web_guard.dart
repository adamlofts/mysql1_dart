import '../mysql_client_error.dart';

/// Reject a MySQL TLS upgrade on a connection the browser is carrying.
///
/// MySQL starts in the clear and then upgrades that same connection. A page
/// cannot do the upgrade, and a bridge only forwards bytes, so turning
/// [useSSL] on would hang or fail with something that looked like a protocol
/// error. Refuse it up front.
Never rejectBridgeTls() {
  throw MySqlClientError(
    'The browser cannot perform MySQL\'s TLS upgrade, '
    'and neither can a connection carried by the bridge. Leave useSSL '
    'false. Use a wss:// bridgeUrl when the page is not served from the '
    'same machine as the bridge, and keep the bridge on a private network '
    'next to the database. A caching_sha2_password account which has not '
    'logged in from the bridge\'s address before needs '
    'ConnectionSettings.serverPublicKey.',
  );
}

/// What a browser connection has to be given before it is attempted.
///
/// A page cannot open a TCP socket, to port 3306 or to anything else. The
/// driver does not try to get around that. [bridgeUrl] is a WebSocket served
/// by `bin/mysql_bridge.dart`, which is what opens the database connection,
/// and [bridgeToken] is the secret that process checks first.
void requireBridge({
  required bool isUnixSocket,
  required bool useSSL,
  required String? bridgeUrl,
  required String? bridgeToken,
}) {
  if (isUnixSocket) {
    throw MySqlClientError(
      'A unix socket cannot be opened from the browser. '
      'The bridge connects to MySQL over TCP, from the machine it runs on.',
    );
  }
  if (useSSL) {
    rejectBridgeTls();
  }
  final url = bridgeUrl;
  if (url == null || url.isEmpty) {
    throw MySqlClientError(
      'The browser cannot open a TCP connection to '
      'MySQL. Run bin/mysql_bridge.dart where it can reach the database '
      'and set ConnectionSettings.bridgeUrl to its ws:// or wss:// '
      'address, and bridgeToken to its MYSQL_BRIDGE_TOKEN. The user, the '
      'password and that token are part of the built web app, so anyone '
      'who can load the app can read them.',
    );
  }
  if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
    throw MySqlClientError(
      'bridgeUrl must be a ws:// or wss:// URL of the '
      'MySQL bridge. It was $url',
    );
  }
  final token = bridgeToken;
  if (token == null || token.isEmpty) {
    throw MySqlClientError(
      'bridgeToken is required whenever bridgeUrl is '
      'set. It is the secret the bridge checks before it opens the '
      'database connection, and it has to match MYSQL_BRIDGE_TOKEN.',
    );
  }
}
