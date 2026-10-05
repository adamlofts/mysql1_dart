library mysql1.rsa;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'mysql_client_error.dart';

// Just enough RSA to send a password to the server: read a public key, and
// encrypt one short message with it. There are no private keys here and
// nothing is decrypted or signed.

/// An RSA public key.
class RsaPublicKey {
  final BigInt modulus;
  final BigInt exponent;

  RsaPublicKey(this.modulus, this.exponent);

  /// The length in bytes of the modulus, and so of anything encrypted with
  /// the key.
  int get byteLength => (modulus.bitLength + 7) ~/ 8;
}

const int _sequence = 0x30;
const int _integer = 0x02;
const int _bitString = 0x03;

/// Read an RSA public key from PEM, which is how the server sends its own.
///
/// Both forms are read: `BEGIN PUBLIC KEY`, which is what the server sends
/// and names the algorithm before the key, and `BEGIN RSA PUBLIC KEY`, which
/// is the key alone.
///
/// Throws [MySqlClientError] if [pem] is not one.
RsaPublicKey parseRsaPublicKeyPem(String pem) {
  try {
    final base64Text = pem
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('-----'))
        .join();
    var der = _DerReader(base64.decode(base64Text)).read(_sequence);
    var first = der.peekTag();
    if (first == _sequence) {
      // The algorithm, then the key wrapped in a bit string whose first byte
      // counts the bits which are not used in its last, always none.
      der.read(_sequence);
      final bits = der.read(_bitString);
      bits.skip(1);
      der = bits.read(_sequence);
      first = der.peekTag();
    }
    if (first != _integer) {
      throw const FormatException('expected the modulus');
    }
    final modulus = der.readInteger();
    final exponent = der.readInteger();
    return RsaPublicKey(modulus, exponent);
  } on MySqlClientError {
    rethrow;
  } catch (e) {
    throw MySqlClientError('Not an RSA public key in PEM format: $e');
  }
}

/// Reads the values of a DER encoding: a tag, a length, and that many bytes.
class _DerReader {
  final Uint8List _bytes;
  int _offset = 0;

  _DerReader(this._bytes);

  int peekTag() => _bytes[_offset];

  void skip(int count) => _offset += count;

  /// The contents of the next value, which has to be a [tag].
  _DerReader read(int tag) {
    if (_bytes[_offset] != tag) {
      throw FormatException('expected tag $tag, found ${_bytes[_offset]}');
    }
    _offset++;
    var length = _bytes[_offset++];
    if (length & 0x80 != 0) {
      // The long form: this byte says how many bytes the length takes.
      final count = length & 0x7f;
      length = 0;
      for (var i = 0; i < count; i++) {
        length = (length << 8) | _bytes[_offset++];
      }
    }
    final contents = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return _DerReader(contents);
  }

  BigInt readInteger() => _bigIntFromBytes(read(_integer)._bytes);
}

BigInt _bigIntFromBytes(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  final bytes = Uint8List(length);
  for (var i = length - 1; i >= 0; i--) {
    bytes[i] = (value & BigInt.from(0xff)).toInt();
    value >>= 8;
  }
  return bytes;
}

const int _hashLength = 20; // sha1

/// The mask generation function of OAEP: as many bytes as asked for, made by
/// hashing [seed] with a counter.
Uint8List _mgf1(List<int> seed, int length) {
  final mask = BytesBuilder();
  for (var counter = 0; mask.length < length; counter++) {
    mask.add(sha1.convert([
      ...seed,
      (counter >> 24) & 0xff,
      (counter >> 16) & 0xff,
      (counter >> 8) & 0xff,
      counter & 0xff,
    ]).bytes);
  }
  return Uint8List.sublistView(mask.takeBytes(), 0, length);
}

/// Encrypt [message] with [key], padded as OAEP with SHA-1 - the padding the
/// server expects of a password, `RSA_PKCS1_OAEP_PADDING`.
///
/// The padding is random, so the same message encrypts differently each
/// time. [random] is for tests and has to be a secure source otherwise.
///
/// Throws [MySqlClientError] if [message] is too long for the key, which
/// leaves room for 214 bytes at the 2048 bits a server uses by default.
Uint8List rsaEncryptOaep(RsaPublicKey key, List<int> message,
    {Random? random}) {
  final k = key.byteLength;
  final maxLength = k - 2 * _hashLength - 2;
  if (message.length > maxLength) {
    throw MySqlClientError('Too long to encrypt with the server\'s public key: '
        '${message.length} bytes, and it has room for $maxLength');
  }

  // The hash of an empty label, zeros, a one, and the message.
  final db = Uint8List(k - _hashLength - 1);
  db.setAll(0, sha1.convert(const <int>[]).bytes);
  db[db.length - message.length - 1] = 1;
  db.setAll(db.length - message.length, message);

  random ??= Random.secure();
  final seed = Uint8List.fromList(
      List.generate(_hashLength, (_) => random!.nextInt(256)));

  final dbMask = _mgf1(seed, db.length);
  for (var i = 0; i < db.length; i++) {
    db[i] ^= dbMask[i];
  }
  final seedMask = _mgf1(db, _hashLength);
  for (var i = 0; i < seed.length; i++) {
    seed[i] ^= seedMask[i];
  }

  final encoded = Uint8List(k)
    ..setAll(1, seed)
    ..setAll(1 + _hashLength, db);
  final encrypted = _bigIntFromBytes(encoded).modPow(key.exponent, key.modulus);
  return _bigIntToBytes(encrypted, k);
}
