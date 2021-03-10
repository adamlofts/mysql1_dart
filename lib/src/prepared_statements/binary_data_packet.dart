library mysql1.binary_data_packet;

import 'package:logging/logging.dart';

import '../constants.dart';

import '../blob.dart';
import '../buffer.dart';

import '../results/field.dart';
import '../results/row.dart';

class BinaryDataPacket extends ResultRow {
  final Logger log = Logger('BinaryDataPacket');

  BinaryDataPacket.forTests(List? _values) {
    values = _values;
  }

  BinaryDataPacket(Buffer buffer, List<Field> fieldPackets) {
    buffer.skip(1);
    var nulls =
        buffer.readList(((fieldPackets.length + 7 + 2) / 8).floor().toInt());
    log.fine('Nulls: $nulls');

    var shift = 2;
    var byte = 0;
    var nullMap = List<bool>.generate(fieldPackets.length, (index) {
      var mask = 1 << shift;
      final value = (nulls[byte] & mask) != 0;
      shift++;
      if (shift > 7) {
        shift = 0;
        byte++;
      }
      return value;
    });

    values = List<dynamic>.filled(fieldPackets.length, null);
    for (var i = 0; i < fieldPackets.length; i++) {
      log.fine('$i: ${fieldPackets[i].name}');
      if (nullMap[i]) {
        log.fine('Value: null');
        values![i] = null;
        continue;
      }
      var field = fieldPackets[i];
      values![i] = readField(field, buffer);
      fields[field.name!] = values![i];
    }
  }

  @override
  Object? readField(Field field, Buffer buffer) {
    switch (field.type) {
      case FIELD_TYPE_BLOB:
        log.fine('BLOB');
        var len = buffer.readLengthCodedBinary();
        if (len == null) {
          return Blob.fromBytes([]);
        }
        var value = Blob.fromBytes(buffer.readList(len));
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_TINY:
        log.fine('TINY');
        var value = buffer.readByte();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_SHORT:
        log.fine('SHORT');
        var value = buffer.readInt16();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_INT24:
        log.fine('INT24');
        var value = buffer.readInt32();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_LONG:
        log.fine('LONG');
        var value = buffer.readInt32();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_LONGLONG:
        log.fine('LONGLONG');
        var value = buffer.readInt64();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_NEWDECIMAL:
        log.fine('NEWDECIMAL');
        var len = buffer.readByte();
        var num = buffer.readString(len);
        var value = double.parse(num);
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_FLOAT:
        log.fine('FLOAT');
        var value = buffer.readFloat();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_DOUBLE:
        log.fine('DOUBLE');
        var value = buffer.readDouble();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_BIT:
        log.fine('BIT');
        var len = buffer.readByte();
        var list = buffer.readList(len);
        var value = 0;
        for (var num in list) {
          value = (value << 8) + num;
        }
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_DATETIME:
      case FIELD_TYPE_DATE:
      case FIELD_TYPE_TIMESTAMP:
        log.fine('DATE/DATETIME');
        var len = buffer.readByte();
        var date = buffer.readList(len);
        var year = 0;
        var month = 0;
        var day = 0;
        var hours = 0;
        var minutes = 0;
        var seconds = 0;
        var billionths = 0;

        if (date.isNotEmpty) {
          year = date[0] + (date[1] << 0x08);
          month = date[2];
          day = date[3];
          if (date.length > 4) {
            hours = date[4];
            minutes = date[5];
            seconds = date[6];
            if (date.length > 7) {
              billionths = date[7] +
                  (date[8] << 0x08) +
                  (date[9] << 0x10) +
                  (date[10] << 0x18);
            }
          }
        }

        var value = DateTime.utc(
            year, month, day, hours, minutes, seconds, billionths ~/ 1000000);
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_TIME:
        log.fine('TIME');
        var len = buffer.readByte();
        var time = buffer.readList(len);

        var sign = 1;
        var days = 0;
        var hours = 0;
        var minutes = 0;
        var seconds = 0;
        var billionths = 0;

        log.fine('time: $time');
        if (time.isNotEmpty) {
          sign = time[0] == 1 ? -1 : 1;
          days = time[1] +
              (time[2] << 0x08) +
              (time[3] << 0x10) +
              (time[4] << 0x18);
          hours = time[5];
          minutes = time[6];
          seconds = time[7];
          if (time.length > 8) {
            billionths = time[8] +
                (time[9] << 0x08) +
                (time[10] << 0x10) +
                (time[11] << 0x18);
          }
        }
        var value = Duration(
            days: days * sign,
            hours: hours * sign,
            minutes: minutes * sign,
            seconds: seconds * sign,
            milliseconds: (billionths ~/ 1000000) * sign);
        return value;
      case FIELD_TYPE_YEAR:
        log.fine('YEAR');
        var value = buffer.readInt16();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_STRING:
        log.fine('STRING');
        var value = buffer.readLengthCodedString();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_VAR_STRING:
        log.fine('STRING');
        var value = buffer.readLengthCodedString();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_GEOMETRY:
        log.fine('GEOMETRY - not implemented');
        var len = buffer.readByte();
        //TODO
        var value = buffer.readList(len);
        return value;
      case FIELD_TYPE_JSON:
        log.fine('Field type  ${field.type}');
        var value = buffer.readLengthCodedString();
        log.fine('Value: $value');
        return value;
      case FIELD_TYPE_NEWDATE:
      case FIELD_TYPE_DECIMAL:
      //TODO pre 5.0.3 will return old decimal values
      case FIELD_TYPE_SET:
      case FIELD_TYPE_ENUM:
      case FIELD_TYPE_TINY_BLOB:
      case FIELD_TYPE_MEDIUM_BLOB:
      case FIELD_TYPE_LONG_BLOB:
      case FIELD_TYPE_VARCHAR:
        //Are there any other types a mysql server can return?
        log.fine('Field type not implemented yet ${field.type}');
        log.fine(buffer.readList(8).toString());
        break;
      default:
        log.fine('Unsupported field type ${field.type}');
        break;
    }
    return null;
  }
}
