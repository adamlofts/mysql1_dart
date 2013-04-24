part of results;

class _ResultsIterator implements Iterator<dynamic> {
  final Results _results;
  List<dynamic> _current;
  int i = 0;
  
  _ResultsIterator._(Results this._results);
  
  List<dynamic> get current => _current; 
  
  bool moveNext() {
    if (i < _results.rows.length) {
      _current = _results.rows[i++].values;
      return true;
    }
    return false;
  }
}
