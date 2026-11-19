/// The text frame a client sends first, before any protocol byte.
///
/// The bridge checks the secret and only then opens the database connection,
/// so a page which does not know it never gets as far as MySQL. The frame is
/// not forwarded. After the bridge replies [bridgeAuthOk], every frame is
/// raw protocol bytes, one WebSocket binary message per chunk.
const String bridgeAuthPrefix = 'mysql1-bridge-auth ';

/// The text frame the bridge sends once the database socket is open.
const String bridgeAuthOk = 'ok';

/// The only path the bridge upgrades to a WebSocket.
const String bridgePath = '/mysql';

/// Whether [presented] is [expected], without returning early on a mismatch.
///
/// A secret compared left to right tells a caller how far the match got, from
/// how long the refusal took. This walks the whole expected value either way.
bool bridgeTokenMatches(String presented, String expected) {
  final a = presented.codeUnits;
  final b = expected.codeUnits;
  if (a.length > 512) {
    return false;
  }
  var diff = a.length ^ b.length;
  for (var i = 0; i < b.length; i++) {
    final unit = i < a.length ? a[i] : 0;
    diff |= unit ^ b[i];
  }
  return diff == 0;
}
