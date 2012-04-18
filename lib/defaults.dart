class ResultsImpl implements Results {
  OkPacket _okPacket;
  List<FieldPacket> _fieldPackets;
  List<DataPacket> _dataPackets;
  ResultSetHeaderPacket _resultSetHeaderPacket;

  ResultsImpl(OkPacket this._okPacket,
    ResultSetHeaderPacket this._resultSetHeaderPacket,
    List<FieldPacket> this._fieldPackets,
    List<DataPacket> this._dataPackets) {
  }
  
  int get insertId() {
    return _okPacket.insertId;
  }
  
  int get affectedRows() {
    return _okPacket.affectedRows;
  }
  
  int get count() {
    return _dataPackets.length;
  }
  
  List<Field> get fields() {
    return _fieldPackets;
  }
  
  List<Dynamic> operator [](int pos) {
    return _dataPackets[pos].values;
  }
  
  Iterator<List<Dynamic>> iterator() {
    return new ResultsImplIterator._internal(this);
  }
}

class ResultsImplIterator implements Iterator<Dynamic> {
  ResultsImpl _results;
  int i = 0;
  
  ResultsImplIterator._internal(ResultsImpl this._results);
  
  bool hasNext() {
    return (i < _results._dataPackets.length);
  }
  
  List<Dynamic> next() {
    return _results._dataPackets[i++].values;
  }
}