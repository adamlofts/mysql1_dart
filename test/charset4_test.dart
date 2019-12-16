import 'package:test/test.dart';

import 'test_infrastructure.dart';

void main() {
  initializeTest(
      'cset4',
      'create table cset4 (stuff4 text character set utf8mb4)',
      "insert into cset4 (stuff4) values ('utf8 テスト 💯😏')");

  group('charset utf8mb4_general_ci tests:', () {
    test('read data', () async {
      var results = await conn.query('select * from cset4');
      expect(results.first.first.toString(), equals('utf8 テスト 💯😏'));
    });
  });
}
