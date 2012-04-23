#library('options');

#import('dart:io');

class OptionsFile {
  Map<String, String> _map;
  
  OptionsFile(String filename) {
    File options = new File(filename);
    _map = <String>{};
    if (options.existsSync()) {
      List<String> lines = options.readAsLinesSync();
      for (String line in lines) {
        if (!line.startsWith('#')) {
          int i = line.indexOf('=');
          String name = line.substring(0, i);
          String value = line.substring(i + 1);
          _map[name] = value;
        }
      }
    } else {
      throw new FileIOException("File not found");
    }
  }
  
  String operator[](String key) => _map[key];
  
  int getInt(String key, [int defaultValue]) {
    int value = Math.parseInt(_map[key]);
    if (value != null) {
      return value;
    }
    return defaultValue;
  }
  
  String getString(String key, [String defaultValue]) {
    String value = _map[key];
    if (value != null) {
      return value;
    }
    return defaultValue;
  }
}