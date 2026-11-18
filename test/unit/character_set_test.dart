library mysql1.character_set_test;

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

void main() {
  // Parameters are escaped on the client, which is only safe when no byte of
  // a multi-byte character can be taken for a quote or a backslash.
  test('a character set which is not utf8 is refused before connecting',
      () async {
    for (final gbkOrSjis in [28, 13]) {
      await expectLater(
          MySqlConnection.connect(
              ConnectionSettings(port: 1, characterSet: gbkOrSjis)),
          throwsA(isA<MySqlClientError>()));
    }
  });

  test('the utf8 and utf8mb4 collations are utf8', () {
    expect(CharacterSet.isUtf8(CharacterSet.UTF8), isTrue);
    expect(CharacterSet.isUtf8(CharacterSet.UTF8MB4), isTrue);
    expect(CharacterSet.isUtf8(255), isTrue); // utf8mb4_0900_ai_ci
    expect(CharacterSet.isUtf8(8), isFalse); // latin1
    expect(CharacterSet.isUtf8(28), isFalse); // gbk
  });
}
