library mysql1.rsa_test;

import 'dart:convert';

import 'package:mysql1/mysql1.dart' show MySqlClientError;
import 'package:mysql1/src/rsa.dart';
import 'package:test/test.dart';

import 'rsa_test_key.dart';

void main() {
  group('reading a public key', () {
    test('in the form the server sends', () {
      final key = parseRsaPublicKeyPem(testPublicKeyPem);
      expect(key.modulus, equals(BigInt.parse(testModulusHex, radix: 16)));
      expect(key.exponent, equals(BigInt.from(testPublicExponent)));
      expect(key.byteLength, equals(256));
    });

    test('in the form without the algorithm', () {
      final key = parseRsaPublicKeyPem(testPublicKeyPkcs1Pem);
      expect(key.modulus, equals(BigInt.parse(testModulusHex, radix: 16)));
      expect(key.exponent, equals(BigInt.from(testPublicExponent)));
    });

    test('with the line endings of another platform', () {
      final key =
          parseRsaPublicKeyPem(testPublicKeyPem.replaceAll('\n', '\r\n'));
      expect(key.modulus, equals(BigInt.parse(testModulusHex, radix: 16)));
    });

    test('refuses what is not a key', () {
      for (final pem in [
        '',
        'not a key',
        '-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----',
        // Valid base64 of a sequence holding a string rather than a key.
        '-----BEGIN PUBLIC KEY-----\n${base64.encode([
              0x30,
              0x03,
              0x0c,
              0x01,
              0x41
            ])}\n-----END PUBLIC KEY-----',
      ]) {
        expect(
            () => parseRsaPublicKeyPem(pem), throwsA(isA<MySqlClientError>()),
            reason: pem);
      }
    });
  });

  group('encrypting', () {
    final key = parseRsaPublicKeyPem(testPublicKeyPem);

    test('what is encrypted can be decrypted with the private key', () {
      final message = utf8.encode('a message');
      final encrypted = rsaEncryptOaep(key, message);
      expect(encrypted, hasLength(256));
      expect(testRsaDecryptOaep(encrypted), equals(message));
    });

    test('an empty message', () {
      expect(testRsaDecryptOaep(rsaEncryptOaep(key, const [])), isEmpty);
    });

    test('the longest message there is room for', () {
      final message = List.generate(214, (i) => i);
      expect(testRsaDecryptOaep(rsaEncryptOaep(key, message)), equals(message));
    });

    test('a message there is not room for is refused', () {
      expect(() => rsaEncryptOaep(key, List.filled(215, 1)),
          throwsA(isA<MySqlClientError>()));
    });

    // The padding is random, which is what stops someone who is listening
    // from telling that the same password was sent twice.
    test('the same message encrypts differently each time', () {
      final message = utf8.encode('a message');
      expect(rsaEncryptOaep(key, message),
          isNot(equals(rsaEncryptOaep(key, message))));
    });
  });
}
