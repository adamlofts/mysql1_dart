library mysql1.ok_packet;

import 'dart:typed_data';

import '../payload.dart';

/// What the server says when a request succeeds and there are no rows.
class OkPacket {
  final int? affectedRows;
  final int? insertId;
  final int serverStatus;
  final int warnings;
  final String message;

  OkPacket._(this.affectedRows, this.insertId, this.serverStatus, this.warnings,
      this.message);

  factory OkPacket(Uint8List payload) {
    final reader = PayloadReader(payload)..skip(1);
    final affectedRows = reader.readLengthEncodedInt();
    final insertId = reader.readLengthEncodedInt();
    final serverStatus = reader.readUint16();
    final warnings = reader.readUint16();
    return OkPacket._(affectedRows, insertId, serverStatus, warnings,
        reader.readRestAsString());
  }

  @override
  String toString() =>
      'OK: affected rows: $affectedRows, insert id: $insertId, '
      'server status: $serverStatus, warnings: $warnings, message: $message';
}
