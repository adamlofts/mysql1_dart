/**
 * [results] is exported by [sqljocky], so there is no need to
 * separately import this library.
 */
library results;

part 'field.dart';
part 'results_iterator.dart';
part 'row.dart';

abstract class Results {
  /**
   * The id of the inserted row, or [null] if no row was inserted.
   */
  int get insertId;
  
  /**
   * The number of affected rows in an update statement, or 
   * [null] in other cases.
   */
  int get affectedRows;
  
  /**
   * A list of the fields returned by the query.
   */
  List<Field> get fields;
  
  /**
   * A list of the rows returned by the query.
   */
  List<Row> get rows;

  /**
   * The number of rows returned by the query.
   * 
   * Deprecated.
   */
  int get count => rows.length;
  
  List<dynamic> operator [](int pos) => rows[pos].values;
  
  Iterator<List<dynamic>> get iterator => new _ResultsIterator._(this);
}
