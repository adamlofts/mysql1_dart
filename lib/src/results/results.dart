part of results;

/**
 * Holds query results.
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
