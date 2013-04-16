part of sqljocky;

class Results {
  final _OkPacket _okPacket;
  final List<Field> _fieldPackets;
  final List<_DataPacket> _dataPackets;
  final _ResultSetHeaderPacket _resultSetHeaderPacket;

  Results._(_OkPacket this._okPacket,
    _ResultSetHeaderPacket this._resultSetHeaderPacket,
    List<Field> this._fieldPackets,
    List<_DataPacket> this._dataPackets);
  
  int get insertId=> _okPacket.insertId;
  
  int get affectedRows => _okPacket.affectedRows;
  
  int get count => _dataPackets.length;
  
  List<Field> get fields => _fieldPackets;
  
  List<dynamic> operator [](int pos) => _dataPackets[pos].values;
  
  Iterator<List<dynamic>> get iterator => new _ResultsIterator._internal(this);
}
