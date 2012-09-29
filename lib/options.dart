library options;

import 'dart:io';
import 'dart:math';

/**
 * [OptionsFile] reads options from a file. The options must be stored in name=value pairs, one pair per line. E.g.:
 *   name=James
 *   age=9
 *   height=256
 * Note that everything on the left of the equals sign is the key, and everything on the right is the value. No stripping
 * of spaces is performed
 */
class OptionsFile {
  Map<String, String> _map;
  
  /**
   * Load options from the file called [filename]
   */
  OptionsFile(String filename) {
    var options = new File(filename);
    _map = <String>{};
    if (options.existsSync()) {
      var lines = options.readAsLinesSync();
      for (var line in lines) {
        if (!line.startsWith('#')) {
          var i = line.indexOf('=');
          var name = line.substring(0, i);
          var value = line.substring(i + 1);
          _map[name] = value;
        }
      }
    } else {
      throw new FileIOException("File not found");
    }
  }
  
  String operator[](String key) => _map[key];
  
  int getInt(String key, [int defaultValue]) {
    var value = _map[key];
    if (value == null) {
      return defaultValue;
    }
    return parseInt(value);
  }
  
  String getString(String key, [String defaultValue]) {
    var value = _map[key];
    if (value != null) {
      return value;
    }
    return defaultValue;
  }
}