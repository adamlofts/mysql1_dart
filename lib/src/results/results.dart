part of results;

/**
 * Holds query results.
 * 
 * If the query was an insert statement, the id of the inserted row is in [insertId].
 * 
 * If the query was an update statement, the number of affected rows is in [affectedRows].
 * 
 * If the query was a select statement, the stream contains the row results and
 * the [fields] are also available.
 */
abstract class Results implements Stream<Row> {
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
