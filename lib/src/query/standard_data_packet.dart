// ignore_for_file: argument_type_not_assignable, return_of_invalid_type, strong_mode_implicit_dynamic_return, strong_mode_implicit_dynamic_variable, invalid_assignment

library mysql1.standard_data_packet;

import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../constants.dart';
import '../blob.dart';
import '../payload.dart';

import '../results/row.dart';
import '../results/field.dart';
import '../results/schema.dart';

class StandardDataPacket extends ResultRow {
  final Logger log = Logger('StandardDataPacket');

  StandardDataPacket(Uint8List row, ResultSchema schema) : super(schema) {
    final reader = PayloadReader(row);
    final fieldPackets = schema.columns;
    values = List<dynamic>.filled(fieldPackets.length, null);
    for (var i = 0; i < fieldPackets.length; i++) {
      var field = fieldPackets[i];

      log.fine('$i: ${field.name}');
      values![i] = readField(field, reader);
      fields[field.name!] = values![i];
    }
  }

  /// Parse a date or datetime string with no timezone as UTC
  ///
  /// Dart does not provide a simple way to do this.
  /// See: https://github.com/adamlofts/mysql1_dart/issues/39
  static DateTime parseDateTimeInUtc(String s) {
    var localTime = DateTime.parse(s);
    return DateTime.utc(
      localTime.year,
      localTime.month,
      localTime.day,
      localTime.hour,
      localTime.minute,
      localTime.second,
      localTime.millisecond,
      localTime.microsecond,
    );
  }

  /// Parse a time string, `[-]HH:MM:SS[.ffffff]`
  ///
  /// The hours run to 838, and the sign applies to the whole value.
  static Duration parseTime(String s) {
    final negative = s.startsWith('-');
    final parts = (negative ? s.substring(1) : s).split(':');
    final seconds = parts[2].split('.');
    final duration = Duration(
        hours: int.parse(parts[0]),
        minutes: int.parse(parts[1]),
        seconds: int.parse(seconds[0]),
        microseconds:
            seconds.length > 1 ? int.parse(seconds[1].padRight(6, '0')) : 0);
    return negative ? -duration : duration;
  }

  /// The next value in [reader], decoded as [field] says.
  Object? readField(ResultSchemaColumn field, PayloadReader reader) {
    final length = reader.readLengthEncodedInt();
    if (length == null) {
      return null;
    }
    final list = reader.readBytes(length);

    switch (ColumnType.of(field.type)) {
      case ColumnType.tiny: // tinyint/bool
      case ColumnType.short: // smallint
      case ColumnType.int24: // mediumint
      case ColumnType.longLong: // bigint/serial
      case ColumnType.long: // int
        var s = utf8.decode(list);
        return int.parse(s);
      case ColumnType.newDecimal: // decimal
      case ColumnType.float: // float
      case ColumnType.double: // double
        var s = utf8.decode(list);
        return double.parse(s);
      case ColumnType.bit: // bit
        var value = 0;
        for (var num in list) {
          value = (value << 8) + num;
        }
        return value;
      case ColumnType.date: // date
      case ColumnType.dateTime: // datetime
      case ColumnType.timestamp: // timestamp
        var s = utf8.decode(list);
        return parseDateTimeInUtc(s);
      case ColumnType.time: // time
        var s = utf8.decode(list);
        return parseTime(s);
      case ColumnType.year: // year
        var s = utf8.decode(list);
        return int.parse(s);
      case ColumnType.json:
        var s = utf8.decode(list);
        return s;
      case ColumnType.string: // char/binary/enum/set
      case ColumnType.varString: // varchar/varbinary
        var s = utf8.decode(list);
        return s;
      case ColumnType.blob:
      case ColumnType.tinyBlob:
      case ColumnType.mediumBlob:
      case ColumnType
            .longBlob: // tinytext/text/mediumtext/longtext/tinyblob/mediumblob/blob/longblob
        return Blob.fromBytes(list);
      case ColumnType.geometry:
        // Well-known binary with the SRID in front: bytes, not text.
        return Blob.fromBytes(list);
      default:
        return null;
    }
  }

  @override
  String toString() => 'Fields: $fields';
}
