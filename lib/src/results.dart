class Results implements Iterable {
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
  
  List<Dynamic> operator [](int pos) => _dataPackets[pos].values;
  
  Iterator<List<Dynamic>> iterator() => new ResultsIterator._internal(this);
}

class ResultsIterator implements Iterator<Dynamic> {
  final Results _results;
  int i = 0;
  
  ResultsIterator._internal(Results this._results);
  
  bool hasNext() => i < _results._dataPackets.length;
  
  List<Dynamic> next() => _results._dataPackets[i++].values;
}