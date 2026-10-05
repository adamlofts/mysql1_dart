library mysql1.substitute_params;

import 'blob.dart';
import 'mysql_client_error.dart';

const int _questionMark = 0x3f; // ?
const int _singleQuote = 0x27; // '
const int _doubleQuote = 0x22; // "
const int _backtick = 0x60; // `
const int _backslash = 0x5c; // \

/// Substitute [values] into [sql], replacing each `?` placeholder with the
/// value written as a SQL literal.
///
/// This is how the driver binds parameters: the statement that reaches the
/// server has no parameters left in it and goes out as a single COM_QUERY,
/// rather than as PREPARE / EXECUTE / CLOSE. It is what the C client does in
/// `mysql_real_escape_string` plus what mysqlclient does in `_mogrify`, and so
/// what most MySQL deployments already send.
///
/// The reason to prefer it is planning. With a bound value the server plans
/// the statement without knowing what the value is: if the leading column of
/// an index is a parameter it takes ref access on that column and never runs
/// the range optimizer, so a keyset page degrades into a scan. Literals let it
/// build the range.
///
/// Two assumptions, both true of a connection this driver opened:
///
/// * The connection charset is ASCII-transparent - utf8 or utf8mb4, the only
///   values [CharacterSet] offers. That is what makes escaping safe without
///   the connection handle: no continuation byte of a UTF-8 sequence can be
///   `\` or `'`, so every such byte really is that character. It does not hold
///   for GBK or SJIS, where a crafted multi-byte sequence can swallow the
///   escape - which is why the C client's `mysql_real_escape_string` takes the
///   connection so it can read the charset.
/// * The server is not in `NO_BACKSLASH_ESCAPES` mode. Backslashes in string
///   values are doubled, which that mode would take literally.
///
/// A `?` inside a quoted string or a backtick identifier is left alone. A `?`
/// inside a comment is not: comments are not parsed, so it counts as a
/// placeholder.
///
/// Throws [MySqlClientError] if the number of placeholders does not match the
/// number of [values], or if a value has no literal form.
String substituteParams(String sql, List<Object?> values) {
  final placeholders = _findPlaceholders(sql);
  if (placeholders.length != values.length) {
    throw MySqlClientError('Length of parameters (${values.length}) does not '
        'match parameter count in query (${placeholders.length})');
  }

  final buffer = StringBuffer();
  var start = 0;
  for (var i = 0; i < placeholders.length; i++) {
    buffer.write(sql.substring(start, placeholders[i]));
    buffer.write(sqlLiteral(values[i]));
    start = placeholders[i] + 1;
  }
  buffer.write(sql.substring(start));
  return buffer.toString();
}

/// The offsets of the `?` placeholders in [sql], skipping any which appear
/// inside a string literal or a quoted identifier.
List<int> _findPlaceholders(String sql) {
  final offsets = <int>[];
  int? quote; // the quote character we are inside, if any

  for (var i = 0; i < sql.length; i++) {
    final c = sql.codeUnitAt(i);

    if (quote != null) {
      if (c == _backslash && quote != _backtick) {
        i++; // an escaped character, which may be the quote itself
      } else if (c == quote) {
        if (i + 1 < sql.length && sql.codeUnitAt(i + 1) == quote) {
          i++; // a doubled quote is an escaped quote, not the end
        } else {
          quote = null;
        }
      }
      continue;
    }

    if (c == _singleQuote || c == _doubleQuote || c == _backtick) {
      quote = c;
    } else if (c == _questionMark) {
      offsets.add(i);
    }
  }
  return offsets;
}

/// [value] written as a SQL literal.
///
/// The types accepted are the ones the driver used to encode into an EXECUTE
/// packet, and they keep the same contract - in particular a [DateTime] must
/// be in UTC. It is written with its fractional seconds when it has any, which
/// the server rounds to the precision of the column.
String sqlLiteral(Object? value) {
  if (value == null) {
    return 'NULL';
  }
  if (value is int) {
    return value.toString();
  }
  if (value is double) {
    if (!value.isFinite) {
      throw MySqlClientError('$value has no SQL literal form');
    }
    return value.toString();
  }
  if (value is DateTime) {
    return _dateTimeLiteral(value);
  }
  if (value is bool) {
    return value ? '1' : '0';
  }
  if (value is List<int>) {
    return _bytesLiteral(value);
  }
  if (value is Blob) {
    return _bytesLiteral(value.toBytes());
  }
  return _stringLiteral(value.toString());
}

String _stringLiteral(String value) {
  // Backslashes first, so the escape introduced for NUL is not doubled.
  // Quotes are doubled rather than backslash-escaped because that form is
  // also correct under NO_BACKSLASH_ESCAPES. A NUL has no such form, and
  // neither " nor Ctrl-Z needs escaping inside a single quoted string - the
  // C client escapes them only because it does not know which quote its
  // caller will use.
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", "''")
      .replaceAll('\u0000', r'\0');
  return "'$escaped'";
}

/// Bytes as a hex literal, which is charset independent - the only form that
/// can carry a byte sequence that is not valid in the connection charset.
String _bytesLiteral(List<int> bytes) {
  if (bytes.isEmpty) {
    return "''"; // X'' is not valid syntax
  }
  const digits = '0123456789abcdef';
  final buffer = StringBuffer("X'");
  for (final byte in bytes) {
    if (byte < 0 || byte > 255) {
      throw MySqlClientError('$byte is not a byte value');
    }
    buffer.write(digits[byte >> 4]);
    buffer.write(digits[byte & 0xf]);
  }
  buffer.write("'");
  return buffer.toString();
}

String _dateTimeLiteral(DateTime value) {
  // The driver requires DateTime values to be in UTC and will always give back
  // a UTC DateTime.
  if (!value.isUtc) {
    throw MySqlClientError('DateTime value is not in UTC');
  }
  String pad(int value, int width) => value.toString().padLeft(width, '0');
  final micros = value.millisecond * 1000 + value.microsecond;
  final fraction = micros == 0 ? '' : '.${pad(micros, 6)}';
  return "'${pad(value.year, 4)}-${pad(value.month, 2)}-${pad(value.day, 2)} "
      "${pad(value.hour, 2)}:${pad(value.minute, 2)}:${pad(value.second, 2)}"
      "$fraction'";
}
