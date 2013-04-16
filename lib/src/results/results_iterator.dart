part of sqljocky;

class _ResultsIterator implements Iterator<dynamic> {
  final Results _results;
  List<dynamic> _current;
  int i = 0;
  
  _ResultsIterator._internal(Results this._results);
  
  List<dynamic> get current => _current; 
  
  bool moveNext() {
    if (i < _results._dataPackets.length) {
      _current = _results._dataPackets[i++].values;
      return true;
    }
    return false;
  }
}
