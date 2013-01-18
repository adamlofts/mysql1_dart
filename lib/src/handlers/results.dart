part of handlers_lib;

class Results {
  final OkPacket _okPacket;
  final List<Field> _fieldPackets;
  final List<DataPacket> _dataPackets;
  final ResultSetHeaderPacket _resultSetHeaderPacket;

  Results(OkPacket this._okPacket,
    ResultSetHeaderPacket this._resultSetHeaderPacket,
    List<Field> this._fieldPackets,
    List<DataPacket> this._dataPackets);
  
  int get insertId=> _okPacket.insertId;
  
  int get affectedRows => _okPacket.affectedRows;
  
  int get count => _dataPackets.length;
  
  List<Field> get fields => _fieldPackets;
  
  List<dynamic> operator [](int pos) => _dataPackets[pos].values;
  
  Iterator<List<dynamic>> get iterator => new ResultsIterator._internal(this);
}

class ResultsIterator implements Iterator<dynamic> {
  final Results _results;
  List<dynamic> _current;
  int i = 0;
  
  ResultsIterator._internal(Results this._results);
  
  List<dynamic> get current => _current; 
  
  bool moveNext() {
    if (i < _results._dataPackets.length) {
      _current = _results._dataPackets[i++].values;
      return true;
    }
    return false;
  }
}