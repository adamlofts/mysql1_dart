/**
 * Basic logger, to use until I find a real one
 */
bool loggingEnabled = true;
 
class Log {
  String _name;
  bool debugEnabled = true;
  
  Log(String this._name);
  
  debug(String message) {
    if (loggingEnabled && debugEnabled) {
      Date now = new Date.now();
      print("$now $_name: $message");
    }
  }
}
