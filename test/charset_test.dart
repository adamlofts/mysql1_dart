import 'package:test/test.dart';

import 'test_infrastructure.dart';

void main() {
  initializeTest('cset', 'create table cset (stuff text character set utf8)',
      "insert into cset (stuff) values ('здрасти')");

  test('read data', () async {
    var results = await conn.query('select * from cset');
    expect(results.first.first.toString(), equals('здрасти'));
  });
}
