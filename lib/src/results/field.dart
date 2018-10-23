library mysql1.field;

import '../buffer.dart';

class Field {
  String _catalog;
  String _db;
  String _table;
  String _orgTable;
  String _name;
  String _orgName;
  int _characterSet;
  int _length;
  int _type;
  int _flags;
  int _decimals;
  int _defaultValue;

  String get catalog => _catalog;
  String get db => _db;
  String get table => _table;
  String get orgTable => _orgTable;
  String get name => _name;
  String get orgName => _orgName;
  int get characterSet => _characterSet;
  int get length => _length;
  int get type => _type;
  int get flags => _flags;
  int get decimals => _decimals;
  int get defaultValue => _defaultValue;

  String get typeString {
    switch (type) {
      case 0x00:
        return "DECIMAL";
      case 0x01:
        return "TINY";
      case 0x02:
        return "SHORT";
      case 0x03:
        return "LONG";
      case 0x04:
        return "FLOAT";
      case 0x05:
        return "DOUBLE";
      case 0x06:
        return "NULL";
      case 0x07:
        return "TIMESTAMP";
      case 0x08:
        return "LONGLONG";
      case 0x09:
        return "INT24";
      case 0x0a:
        return "DATE";
      case 0x0b:
        return "TIME";
      case 0x0c:
        return "DATETIME";
      case 0x0d:
        return "YEAR";
      case 0x0e:
        return "NEWDATE";
      case 0x0f:
        return "VARCHAR";
      case 0x10:
        return "BIT";
      case 0xf6:
        return "NEWDECIMAL";
      case 0xf7:
        return "ENUM";
      case 0xf8:
        return "SET";
      case 0xf9:
        return "TINY_BLOB";
      case 0xfa:
        return "MEDIUM_BLOB";
      case 0xfb:
        return "LONG_BLOB";
      case 0xfc:
        return "BLOB";
      case 0xfd:
        return "VAR_STRING";
      case 0xfe:
        return "STRING";
      case 0xff:
        return "GEOMETRY";
      default:
        return "UNKNOWN";
    }
  }

  Field.forTests(this._type);

  void setName(String value) {
    this._name = value;
  }

  Field(Buffer buffer) {
    _catalog = buffer.readLengthCodedString();
    _db = buffer.readLengthCodedString();
    _table = buffer.readLengthCodedString();
    _orgTable = buffer.readLengthCodedString();
    _name = buffer.readLengthCodedString();
    _orgName = buffer.readLengthCodedString();
    buffer.skip(1);
    _characterSet = buffer.readUint16();
    _length = buffer.readUint32();
    _type = buffer.readByte();
    _flags = buffer.readUint16();
    _decimals = buffer.readByte();
    buffer.skip(2);
    if (buffer.canReadMore()) {
      _defaultValue = buffer.readLengthCodedBinary();
    }
  }

  String toString() =>
      "Catalog: $_catalog, DB: $_db, Table: $_table, Org Table: $_orgTable, "
      "Name: $_name, Org Name: $_orgName, Character Set: $_characterSet, "
      "Length: $_length, Type: $_type, Flags: $_flags, Decimals: $_decimals, "
      "Default Value: $_defaultValue";
}
