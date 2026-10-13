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
  static final Logger _log = Logger('StandardDataPacket');

  StandardDataPacket(Uint8List row, ResultSchema schema) : super(schema) {
    final reader = PayloadReader(row);
    values = [
      for (final column in schema.columns) readField(column, reader),
    ];
    _log.finest(() => 'row $values');
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

    return switch (ColumnType.of(field.type)) {
      // tinyint/bool, smallint, mediumint, int, bigint/serial, year
      ColumnType.tiny ||
      ColumnType.short ||
      ColumnType.int24 ||
      ColumnType.long ||
      ColumnType.longLong ||
      ColumnType.year =>
        int.parse(utf8.decode(list)),
      // decimal, float, double
      ColumnType.newDecimal ||
      ColumnType.float ||
      ColumnType.double =>
        double.parse(utf8.decode(list)),
      // bit, big endian over as many bytes as the declared width needs
      ColumnType.bit => list.fold<int>(0, (value, byte) => (value << 8) + byte),
      // date, datetime, timestamp
      ColumnType.date ||
      ColumnType.dateTime ||
      ColumnType.timestamp =>
        parseDateTimeInUtc(utf8.decode(list)),
      ColumnType.time => parseTime(utf8.decode(list)),
      // char/binary/enum/set, varchar/varbinary and json, all as text
      ColumnType.string ||
      ColumnType.varString ||
      ColumnType.json =>
        utf8.decode(list),
      // tinytext/text/mediumtext/longtext and the blob types as bytes, and
      // geometry, which is well-known binary with the SRID in front
      ColumnType.tinyBlob ||
      ColumnType.blob ||
      ColumnType.mediumBlob ||
      ColumnType.longBlob ||
      ColumnType.geometry =>
        Blob.fromBytes(list),
      // A type this driver does not know.
      null => null,
    };
  }
}
