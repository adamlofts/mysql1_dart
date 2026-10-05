library mysql1.field;

import '../buffer.dart';

/// A column of a result.
class ResultSchemaColumn {
  final String? catalog;
  final String? db;
  final String? table;
  final String? orgTable;
  final String? name;
  final String? orgName;
  final int? characterSet;
  final int? length;
  final int? type;
  final int? flags;
  final int? decimals;
  final int? defaultValue;

  /// The name of the column in the result, which is its alias if it was
  /// given one. The same as [name].
  String? get columnName => name;

  String get typeString {
    switch (type) {
      case 0x00:
        return 'DECIMAL';
      case 0x01:
        return 'TINY';
      case 0x02:
        return 'SHORT';
      case 0x03:
        return 'LONG';
      case 0x04:
        return 'FLOAT';
      case 0x05:
        return 'DOUBLE';
      case 0x06:
        return 'NULL';
      case 0x07:
        return 'TIMESTAMP';
      case 0x08:
        return 'LONGLONG';
      case 0x09:
        return 'INT24';
      case 0x0a:
        return 'DATE';
      case 0x0b:
        return 'TIME';
      case 0x0c:
        return 'DATETIME';
      case 0x0d:
        return 'YEAR';
      case 0x0e:
        return 'NEWDATE';
      case 0x0f:
        return 'VARCHAR';
      case 0x10:
        return 'BIT';
      case 0xf5:
        return 'JSON';
      case 0xf6:
        return 'NEWDECIMAL';
      case 0xf7:
        return 'ENUM';
      case 0xf8:
        return 'SET';
      case 0xf9:
        return 'TINY_BLOB';
      case 0xfa:
        return 'MEDIUM_BLOB';
      case 0xfb:
        return 'LONG_BLOB';
      case 0xfc:
        return 'BLOB';
      case 0xfd:
        return 'VAR_STRING';
      case 0xfe:
        return 'STRING';
      case 0xff:
        return 'GEOMETRY';
      default:
        return 'UNKNOWN';
    }
  }

  ResultSchemaColumn._internal(
      this.catalog,
      this.db,
      this.table,
      this.orgTable,
      this.name,
      this.orgName,
      this.characterSet,
      this.length,
      this.type,
      this.flags,
      this.decimals,
      this.defaultValue);
  ResultSchemaColumn.forTests(this.type)
      : catalog = null,
        db = null,
        table = null,
        orgTable = null,
        name = null,
        orgName = null,
        characterSet = null,
        length = null,
        flags = null,
        decimals = null,
        defaultValue = null;

  factory ResultSchemaColumn(Buffer buffer) {
    final catalog = buffer.readLengthCodedString();
    final db = buffer.readLengthCodedString();
    final table = buffer.readLengthCodedString();
    final orgTable = buffer.readLengthCodedString();
    final name = buffer.readLengthCodedString();
    final orgName = buffer.readLengthCodedString();
    buffer.skip(1);
    final characterSet = buffer.readUint16();
    final length = buffer.readUint32();
    final type = buffer.readByte();
    final flags = buffer.readUint16();
    final decimals = buffer.readByte();
    buffer.skip(2);
    int? defaultValue;
    if (buffer.canReadMore()) {
      defaultValue = buffer.readLengthCodedBinary();
    }
    return ResultSchemaColumn._internal(catalog, db, table, orgTable, name,
        orgName, characterSet, length, type, flags, decimals, defaultValue);
  }

  @override
  String toString() =>
      'Catalog: $catalog, DB: $db, Table: $table, Org Table: $orgTable, '
      'Name: $name, Org Name: $orgName, Character Set: $characterSet, '
      'Length: $length, Type: $type, Flags: $flags, Decimals: $decimals, '
      'Default Value: $defaultValue';
}

/// The name [ResultSchemaColumn] had before.
@Deprecated('Use ResultSchemaColumn')
typedef Field = ResultSchemaColumn;
