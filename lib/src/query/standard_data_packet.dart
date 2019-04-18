// ignore_for_file: argument_type_not_assignable, return_of_invalid_type, strong_mode_implicit_dynamic_return, strong_mode_implicit_dynamic_variable, invalid_assignment

library mysql1.standard_data_packet;

import 'dart:convert';
import 'package:logging/logging.dart';

import '../constants.dart';
import '../blob.dart';
import '../buffer.dart';

import '../results/row.dart';
import '../results/field.dart';

class StandardDataPacket extends Row {
  final Logger log = new Logger("StandardDataPacket");

  /// Values as Map
  final Map<String, dynamic> fields = <String, dynamic>{};

  StandardDataPacket(Buffer buffer, List<Field> fieldPackets) {
    values = new List<dynamic>(fieldPackets.length);
    for (var i = 0; i < fieldPackets.length; i++) {
      var field = fieldPackets[i];

      log.fine("$i: ${field.name}");

      values[i] = readField(field, buffer);
      fields[field.name] = values[i];
    }
  }

  Object readField(Field field, Buffer buffer) {
    var list;
    int length = buffer.readLengthCodedBinary();
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
        break;
      case FIELD_TYPE_NEWDECIMAL: // decimal
      case FIELD_TYPE_FLOAT: // float
      case FIELD_TYPE_DOUBLE: // double
        var s = utf8.decode(list);
        return double.parse(s);
        break;
      case FIELD_TYPE_BIT: // bit
        var value = 0;
        for (var num in list) {
          value = (value << 8) + num;
        }
        return value;
        break;
      case FIELD_TYPE_DATE: // date
      case FIELD_TYPE_DATETIME: // datetime
      case FIELD_TYPE_TIMESTAMP: // timestamp
        var s = utf8.decode(list);
        return DateTime.parse(s).toUtc();
        break;
      case FIELD_TYPE_TIME: // time
        var s = utf8.decode(list);
        var parts = s.split(":");
        return new Duration(
            days: 0,
            hours: int.parse(parts[0]),
            minutes: int.parse(parts[1]),
            seconds: int.parse(parts[2]),
            milliseconds: 0);
        break;
      case FIELD_TYPE_YEAR: // year
        var s = utf8.decode(list);
        return int.parse(s);
        break;
      case FIELD_TYPE_STRING: // char/binary/enum/set
      case FIELD_TYPE_VAR_STRING: // varchar/varbinary
        var s = utf8.decode(list);
        return s;
        break;
      case FIELD_TYPE_BLOB: // tinytext/text/mediumtext/longtext/tinyblob/mediumblob/blob/longblob
        return new Blob.fromBytes(list);
        break;
      case FIELD_TYPE_GEOMETRY: // geometry
        var s = utf8.decode(list);
        return s;
        break;
    }
  }

  String toString() => "Fields: $fields";
}
