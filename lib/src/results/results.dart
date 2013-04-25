part of results;

/**
* Holds a list of query results.
*
* Most of these fields and methods are inherited from [ListBase].
* The ones added here are [insertId], [affectedRows] and [fields].
*/
abstract class Results extends ListBase<Row> {
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
}
