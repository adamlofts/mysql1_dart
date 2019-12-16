library mysql1.blob;

import 'dart:convert';

import 'package:collection/collection.dart';

const _listQuality = ListEquality<int>();

/// Holds blob data, and can be created or accessed as either a [String] or a [List] of
/// 8-bit integers.
///
/// When a blob which was created as a list of integers is accessed as a string, those
/// integers are treated as UTF-8 code units (unsigned 8-bit integers).
class Blob {
  final List<int> _codeUnits;

  /// Create a [Blob] from a [string].
  factory Blob.fromString(String string) => Blob.fromBytes(utf8.encode(string));

  /// Create a [Blob] from a list of [codeUnits].
  Blob.fromBytes(List<int> codeUnits) : _codeUnits = codeUnits;

  /// Returns the value of the blob as a [String].
  @override
  String toString() => utf8.decode(_codeUnits, allowMalformed: true);

  /// Returns the value of the blob as a list of code units.
  List<int> toBytes() => _codeUnits;

  @override
  int get hashCode => _listQuality.hash(_codeUnits);

  @override
  bool operator ==(Object other) =>
      other is Blob && _listQuality.equals(_codeUnits, other.toBytes());
}
