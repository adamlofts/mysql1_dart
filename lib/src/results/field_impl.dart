part of sqljocky;

class _FieldImpl implements Field {
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

  _FieldImpl._forTests(this._type);

  _FieldImpl._(Buffer buffer) {
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
  
  String toString() => "Catalog: $_catalog, DB: $_db, Table: $_table, Org Table: $_orgTable, " 
       "Name: $_name, Org Name: $_orgName, Character Set: $_characterSet, "
       "Length: $_length, Type: $_type, Flags: $_flags, Decimals: $_decimals, "
       "Default Value: $_defaultValue";
}
