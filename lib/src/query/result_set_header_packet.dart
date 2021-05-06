library mysql1.result_set_header_packet;

import 'package:logging/logging.dart';

import '../buffer.dart';

class ResultSetHeaderPacket {
  late final int? _fieldCount;
  int? _extra;
  Logger log;

  int? get fieldCount => _fieldCount;

  ResultSetHeaderPacket(Buffer buffer)
      : log = Logger('ResultSetHeaderPacket'),
        _fieldCount = buffer.readLengthCodedBinary() {
    if (buffer.canReadMore()) {
      _extra = buffer.readLengthCodedBinary();
    }
  }

  @override
  String toString() => 'Field count: $_fieldCount, Extra: $_extra';
}
