part of sqljocky;

void runAuthHandlerTests() {
  group('auth_handler:', () {
    test('check one set of values', () {
      var handler = new _AuthHandler('username', 'password', 'db',
          [1, 2, 3, 4], 0, 100, 0);
      var buffer = handler.createRequest();
      expect(buffer.list.length, equals(65));
      expect(buffer.list.sublist(32, 40), UTF8.encode("username"));
      expect(buffer.list, equals([8, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
                                   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
                                   117, 115, 101, 114, 110, 97, 109, 101, 
                                   0, 20, 211, 136, 65, 109, 153, 241, 227, 117, 168, 
                                   83, 80, 136, 188, 116, 50, 54, 235, 225, 54, 225, 100, 98, 0]));
//      print(buffer._list);
//      print(_Buffer.listChars(buffer._list));
    });

    test('check another set of values', () {
      var handler = new _AuthHandler('iamtheuserwantingtologin', 'wibblededee', 'thisisthenameofthedatabase',
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], 2435623, 34536, 2345);
      var buffer = handler.createRequest();
      expect(buffer.list.length, equals(105));
      expect(buffer.list.sublist(32, 40), UTF8.encode("iamtheus"));
      expect(buffer.list, equals([47, 42, 37, 0, 232, 134, 0, 0, 41, 0, 0, 0, 0,
                                   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
                                   105, 97, 109, 116, 104, 101, 117, 115, 101, 114, 119,
                                   97, 110, 116, 105, 110, 103, 116, 111, 108, 111, 103,
                                   105, 110, 0, 20, 246, 116, 90, 158, 252, 237, 202, 111, 
                                   0, 86, 96, 154, 242, 51, 178, 245, 188, 55, 250, 15, 
                                   116, 104, 105, 115, 105, 115, 116, 104, 101, 110, 97,
                                   109, 101, 111, 102, 116, 104, 101, 100, 97, 116, 97, 98,
                                   97, 115, 101, 0]));
    });
  });
  
  test('check utf8', () {
    var handler = new _AuthHandler('Борис', 'здрасти', 'db',
        [1, 2, 3, 4], 0, 100, 0);
    var buffer = handler.createRequest();
    expect(buffer.list.sublist(32, 42), UTF8.encode("Борис"));
  });
}
