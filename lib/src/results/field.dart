part of results;

//TODO document these fields
/// A MySQL field
abstract class Field {
  String get catalog;
  String get db;
  String get table;
  String get orgTable;
  
  /// The name of the field
  String get name;
  String get orgName;
  int get characterSet;
  int get length;
  int get type;
  int get flags;
  int get decimals;
  int get defaultValue;
}
