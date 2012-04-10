/**
 * Basic logger, to use until I find a real one
 */
bool loggingEnabled = true;
 
class Log {
  static Map<String, Log> _loggers;
  
  factory Log(String name) {
    if (_loggers == null) {
      _loggers = new Map<String, Log>();
    }
    Log logger = _loggers[name];
    if (logger == null) {
      logger = new Log._internal(name);
      _loggers[name] = logger;
    }
    return logger;
  }
  
  Log._internal(String this._name);
  
  String _name;
  bool debugEnabled = true;
  
  debug(String message) {
    if (loggingEnabled && debugEnabled) {
      Date now = new Date.now();
      print("$now $_name: $message");
    }
  }
}
