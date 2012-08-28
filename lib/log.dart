/**
 * Basic logger, to use until I find a real one
 */
 
class Log {
  final String _name;
  bool _debugEnabled = true;
  static bool _loggingEnabled;
  
  static Map<String, Log> _loggers;
  
  static initialize([bool loggingEnabled=true]) {
    if (_loggers == null) {
      _loggers = <Log>{};
    }
    _loggingEnabled = loggingEnabled;
  }
  
  static bool get loggingEnabled => _loggingEnabled;
  static void set loggingEnabled(bool loggingEnabled) {
    _loggingEnabled = loggingEnabled;
  }
  
  bool get debugEnabled => _debugEnabled;
  void set debugEnabled(bool debugEnabled) {
    _debugEnabled = debugEnabled;
  }
    
  factory Log(String name) {
    Log logger = _loggers[name];
    if (logger == null) {
      logger = new Log._internal(name);
      _loggers[name] = logger;
    }
    return logger;
  }
  
  Log._internal(String this._name);
  
  debug(Dynamic message) {
    if (Log._loggingEnabled && _debugEnabled) {
      Date now = new Date.now();
      print("$now $_name: $message");
    }
  }
  
  static logDebug(String logger, Dynamic message) {
    Log log = new Log(logger);
    log.debug(message);
  }
}
