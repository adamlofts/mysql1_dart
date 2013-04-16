part of sqljocky;

abstract class _DataPacket {
  List<dynamic> get values;
  _DataPacket(Buffer buffer, List<Field> fieldPackets);
}
