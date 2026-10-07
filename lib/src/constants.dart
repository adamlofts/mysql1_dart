library mysql1.constants;

/// The values of the client/server protocol which this driver uses, from the
/// protocol documentation. The links are to the page each group is on.
///
/// Only what the driver sends or checks is here.

/// The first byte of a payload from the server, where it says which kind of
/// packet it is. The rest of the payload depends on it.
///
/// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_response_packets.html
/// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_connection_phase_packets.html
abstract final class Packet {
  static const int ok = 0x00;
  static const int error = 0xff;
  static const int eof = 0xfe;

  /// During authentication: data for the plugin in use.
  static const int authMoreData = 0x01;

  /// During authentication: carry on with another plugin. The same byte as
  /// [eof], which cannot arrive during authentication.
  static const int authSwitch = 0xfe;
}

/// What the client and server each say they can do. The greeting carries the
/// server's, and the handshake response the client's, as bits or'd together.
///
/// https://dev.mysql.com/doc/dev/mysql-server/latest/group__group__cs__capabilities__flags.html
enum Capability {
  longPassword(1 << 0),
  longFlag(1 << 2),
  connectWithDb(1 << 3),
  protocol41(1 << 9),
  ssl(1 << 11),
  transactions(1 << 13),
  secureConnection(1 << 15),
  multiResults(1 << 17),
  pluginAuth(1 << 19);

  const Capability(this.bit);

  final int bit;
}

/// The bits of the server status in an ok or eof packet.
///
/// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_ok_packet.html
enum ServerStatus {
  /// Another result set follows this one.
  moreResults(1 << 3);

  const ServerStatus(this.bit);

  final int bit;
}

/// The first byte of a request, saying what the client wants done.
///
/// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_command_phase.html
enum Command {
  quit(0x01),
  query(0x03);

  const Command(this.code);

  final int code;
}

/// The type of a column, as the server gives it in a column definition.
///
/// https://dev.mysql.com/doc/dev/mysql-server/latest/field__types_8h.html
enum ColumnType {
  tiny(0x01),
  short(0x02),
  long(0x03),
  float(0x04),
  double(0x05),
  timestamp(0x07),
  longLong(0x08),
  int24(0x09),
  date(0x0a),
  time(0x0b),
  dateTime(0x0c),
  year(0x0d),
  bit(0x10),
  json(0xf5),
  newDecimal(0xf6),
  tinyBlob(0xf9),
  mediumBlob(0xfa),
  longBlob(0xfb),
  blob(0xfc),
  varString(0xfd),
  string(0xfe),
  geometry(0xff);

  const ColumnType(this.code);

  final int code;

  static final Map<int, ColumnType> _byCode = {
    for (final type in values) type.code: type
  };

  /// The type with [code], or null for one this driver does not know.
  static ColumnType? of(int? code) => _byCode[code];
}

/// The character sets a connection can be opened with. Both are utf8, which
/// is what makes binding parameters as literals safe.
///
/// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_character_set.html
class CharacterSet {
  static const int UTF8 = 33;
  static const int UTF8MB4 = 45;
}
