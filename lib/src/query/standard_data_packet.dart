// ignore_for_file: argument_type_not_assignable, return_of_invalid_type, strong_mode_implicit_dynamic_return, strong_mode_implicit_dynamic_variable, invalid_assignment

library mysql1.standard_data_packet;

import 'dart:convert';
import 'package:logging/logging.dart';

import '../constants.dart';
import '../blob.dart';
import '../buffer.dart';

import '../results/row.dart';
import '../results/field.dart';

class StandardDataPacket extends ResultRow {
  final Logger log = Logger('StandardDataPacket');

  /// Values as Map
  @override
  final Map<String, dynamic> fields = <String, dynamic>{};

  StandardDataPacket(Buffer buffer, List<Field> fieldPackets) {
    values = List<dynamic>.filled(fieldPackets.length, null);
    for (var i = 0; i < fieldPackets.length; i++) {
      var field = fieldPackets[i];

      log.fine('$i: ${field.name}');
      values![i] = readField(field, buffer);
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

  @override
  Object? readField(Field field, Buffer buffer) {
    List<int> list;
    var length = buffer.readLengthCodedBinary();
    if (length != null) {
      list = buffer.readList(length);
    } else {
      return null;
    }

    switch (field.type) {
      case FIELD_TYPE_TINY: // tinyint/bool
      case FIELD_TYPE_SHORT: // smallint
      case FIELD_TYPE_INT24: // mediumint
      case FIELD_TYPE_LONGLONG: // bigint/serial
      case FIELD_TYPE_LONG: // int
        var s = utf8.decode(list);
        return int.parse(s);
      case FIELD_TYPE_NEWDECIMAL: // decimal
      case FIELD_TYPE_FLOAT: // float
      case FIELD_TYPE_DOUBLE: // double
        var s = utf8.decode(list);
        return double.parse(s);
      case FIELD_TYPE_BIT: // bit
        var value = 0;
        for (var num in list) {
          value = (value << 8) + num;
        }
        return value;
      case FIELD_TYPE_DATE: // date
      case FIELD_TYPE_DATETIME: // datetime
      case FIELD_TYPE_TIMESTAMP: // timestamp
        var s = utf8.decode(list);
        return parseDateTimeInUtc(s);
      case FIELD_TYPE_TIME: // time
        var s = utf8.decode(list);
        var parts = s.split(':');
        return Duration(
            days: 0,
            hours: int.parse(parts[0]),
            minutes: int.parse(parts[1]),
            seconds: int.parse(parts[2]),
            milliseconds: 0);
      case FIELD_TYPE_YEAR: // year
        var s = utf8.decode(list);
        return int.parse(s);
      case FIELD_TYPE_JSON:
        var s = utf8.decode(list);
        return s;
      case FIELD_TYPE_STRING: // char/binary/enum/set
      case FIELD_TYPE_VAR_STRING: // varchar/varbinary
        var s = utf8.decode(list);
        return s;
      case FIELD_TYPE_BLOB:
      case FIELD_TYPE_TINY_BLOB:
      case FIELD_TYPE_MEDIUM_BLOB:
      case FIELD_TYPE_LONG_BLOB: // tinytext/text/mediumtext/longtext/tinyblob/mediumblob/blob/longblob
        return Blob.fromBytes(list);
      case FIELD_TYPE_GEOMETRY: // geometry
        var s = utf8.decode(list);
        return s;
      default:
        return null;
    }
  }

  @override
  String toString() => 'Fields: $fields';
}
