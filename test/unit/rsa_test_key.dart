import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// An RSA key pair for the tests, made for them and used for nothing else.
// The private half is here so that a test can decrypt what the driver
// encrypted and see that it is what the server would have read.

/// The public key, in the form a server sends its own.
const testPublicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsbqfUN7zb8SnGrZRS5FD
iFCzLiXQwhIF2loZrNHMewgMqj9mtpwBujrLGflT8YkfJCTTPvxiLsSulZsvVGEi
YJBskUBzZSnHGLlknCAaSwHgxiWJxS/uKSrbsGqrxqHRPnlyhglEQx31d5ZSstNk
FEiA4egK3fDzPbBCb7hbnjfZHWc5puYADUX5qxRPU7TRIxO0xjO/Dxkcf5hAJOL5
GdkAsLl9bc1f/lSfWZhkic3CoLv8AhabJcS8QC7uxkEbXYYbMcRxeKIbrHbe2Sma
YmrMyShbZmyysUjX7r0ufs8Q0fa+Ca6J6sW0ZZnlrJG/dhe/u+Ekkf9ttcBDW3BF
PQIDAQAB
-----END PUBLIC KEY-----
''';

/// The same key in the older form, which is the key with no algorithm
/// before it.
const testPublicKeyPkcs1Pem = '''
-----BEGIN RSA PUBLIC KEY-----
MIIBCgKCAQEAsbqfUN7zb8SnGrZRS5FDiFCzLiXQwhIF2loZrNHMewgMqj9mtpwB
ujrLGflT8YkfJCTTPvxiLsSulZsvVGEiYJBskUBzZSnHGLlknCAaSwHgxiWJxS/u
KSrbsGqrxqHRPnlyhglEQx31d5ZSstNkFEiA4egK3fDzPbBCb7hbnjfZHWc5puYA
DUX5qxRPU7TRIxO0xjO/Dxkcf5hAJOL5GdkAsLl9bc1f/lSfWZhkic3CoLv8Ahab
JcS8QC7uxkEbXYYbMcRxeKIbrHbe2SmaYmrMyShbZmyysUjX7r0ufs8Q0fa+Ca6J
6sW0ZZnlrJG/dhe/u+Ekkf9ttcBDW3BFPQIDAQAB
-----END RSA PUBLIC KEY-----
''';

const testModulusHex =
    'b1ba9f50def36fc4a71ab6514b91438850b32e25d0c21205da5a19acd1cc7b08'
    '0caa3f66b69c01ba3acb19f953f1891f2424d33efc622ec4ae959b2f54612260'
    '906c9140736529c718b9649c201a4b01e0c62589c52fee292adbb06aabc6a1d1'
    '3e7972860944431df5779652b2d364144880e1e80addf0f33db0426fb85b9e37'
    'd91d6739a6e6000d45f9ab144f53b4d12313b4c633bf0f191c7f984024e2f919'
    'd900b0b97d6dcd5ffe549f59986489cdc2a0bbfc02169b25c4bc402eeec6411b'
    '5d861b31c47178a21bac76ded9299a626accc9285b666cb2b148d7eebd2e7ecf'
    '10d1f6be09ae89eac5b46599e5ac91bf7617bfbbe12491ff6db5c0435b70453d';

const testPrivateExponentHex =
    '01fe44d1245ef88eed0cd8a49ac35b4d8912295f553307feb6cf31e0854dd4c7'
    '6754f577126f3779be350eea83ed7e8b31dd93dcedf9afea96c6a8c1e4215ec0'
    '547e5336b4d49a9e5801a44637f9f38366e0f204d4885014781d94a1eda141a9'
    '56190896c63dd4bede44e413b35bb9909cab8d5d0bda275ca3017a0d44b50a56'
    '3338f3bf7d1a388e3269ff0c914ad52dc3a3a6a3b158524b62211fc878534dda'
    '13ffd07364b65bf45a829bed5c25814deb2e6ecac250783ec90a37b12c13ccb9'
    '2a82145011a371bac47f735f3103f8a9a6672a5bc3b163b91f56c6d00b9bcd16'
    '7990b7ff6fe71f4e50c1161735aa1163e17f6ee41a42157813aabc8495bc3901';

const testPublicExponent = 65537;

BigInt _fromBytes(List<int> bytes) =>
    bytes.fold(BigInt.zero, (value, byte) => (value << 8) | BigInt.from(byte));

Uint8List _mgf1(List<int> seed, int length) {
  final mask = <int>[];
  for (var counter = 0; mask.length < length; counter++) {
    mask.addAll(
        sha1.convert([...seed, 0, 0, counter >> 8, counter & 0xff]).bytes);
  }
  return Uint8List.fromList(mask.sublist(0, length));
}

/// Decrypt [encrypted] with the test key and take off the OAEP padding, as a
/// server does with a password it is sent. Throws if the padding is wrong.
List<int> testRsaDecryptOaep(List<int> encrypted) {
  final modulus = BigInt.parse(testModulusHex, radix: 16);
  final privateExponent = BigInt.parse(testPrivateExponentHex, radix: 16);
  final k = (modulus.bitLength + 7) ~/ 8;
  if (encrypted.length != k) {
    throw StateError('Expected $k bytes and got ${encrypted.length}');
  }

  var value = _fromBytes(encrypted).modPow(privateExponent, modulus);
  final encoded = Uint8List(k);
  for (var i = k - 1; i >= 0; i--) {
    encoded[i] = (value & BigInt.from(0xff)).toInt();
    value >>= 8;
  }

  const hashLength = 20;
  final seed = encoded.sublist(1, 1 + hashLength);
  final db = encoded.sublist(1 + hashLength);
  final seedMask = _mgf1(db, hashLength);
  for (var i = 0; i < seed.length; i++) {
    seed[i] ^= seedMask[i];
  }
  final dbMask = _mgf1(seed, db.length);
  for (var i = 0; i < db.length; i++) {
    db[i] ^= dbMask[i];
  }

  final labelHash = sha1.convert(const <int>[]).bytes;
  var start = hashLength;
  while (start < db.length && db[start] == 0) {
    start++;
  }
  if (encoded[0] != 0 ||
      !_equal(db.sublist(0, hashLength), labelHash) ||
      start == db.length ||
      db[start] != 1) {
    throw StateError('Not OAEP padding');
  }
  return db.sublist(start + 1);
}

bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
