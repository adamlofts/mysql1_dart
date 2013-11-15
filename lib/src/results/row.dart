part of results;

/**
 * A row of data. Fields can be retrieved by index, or by name.
 * 
 * When retrieving a field by name, only fields which are valid Dart
 * identifiers, and which aren't part of the List object, can be used.
 */
@proxy
abstract class Row extends ListBase<dynamic> {
}
