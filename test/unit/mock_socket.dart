import 'dart:async';

import 'dart:io';

import 'dart:typed_data';

class MockSocket extends StreamView<RawSocketEvent> implements RawSocket {
  MockSocket(StreamController<RawSocketEvent> streamController)
      : _streamController = streamController,
        _data = <int>[],
        super(streamController.stream);

  final StreamController<RawSocketEvent> _streamController;

  final List<int> _data;
  @override
  int available() => _data.length;

  @override
  Uint8List? read([int? len]) {
    var count = len ?? 0;
    if (count > _data.length) {
      count = _data.length;
    }
    var data = _data.getRange(0, count);
    var list = Uint8List(data.length);
    list.setRange(0, data.length, data);
    _data.removeRange(0, count);
    return list;
  }

  void addData(List<int> data) {
    _data.addAll(data);
    _streamController.add(RawSocketEvent.READ);
  }

  void closeRead() {
    _streamController.add(RawSocketEvent.READ_CLOSED);
  }

  @override
  set writeEventsEnabled(bool value) {
    if (value) {
      _streamController.add(RawSocketEvent.WRITE);
    }
  }

  @override
  bool setOption(SocketOption option, bool enabled) => true; // No-op

  @override
  Object noSuchMethod(a) => super.noSuchMethod(a);
}
