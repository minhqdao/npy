import 'dart:typed_data';

import 'package:npy/src/np_exception.dart';

class NDArray<T> {
  const NDArray({
    required this.version,
    required this.headerLength,
    required this.header,
    required this.data,
  });

  final NpyVersion version;
  final int headerLength;
  final NpyHeader header;
  final List<T> data;
}

// class NpzFile {
//   const NpzFile({
//     required this.files,
//   });

//   final Map<String, NDArray> files;
// }

class NpyVersion {
  const NpyVersion({
    this.major = 1,
    this.minor = 0,
  });

  final int major;
  final int minor;

  static const reservedBytes = 2;

  static const _supportedMajorVersions = {1, 2, 3};
  static const _supportedMinorVersions = {0};

  factory NpyVersion.fromBytes(Iterable<int> bytes) {
    assert(bytes.length == reservedBytes);
    if (!_supportedMajorVersions.contains(bytes.elementAt(0))) {
      throw NpyUnsupportedVersionException(message: 'Unsupported major version: ${bytes.elementAt(0)}');
    }
    if (!_supportedMinorVersions.contains(bytes.elementAt(1))) {
      throw NpyUnsupportedVersionException(message: 'Unsupported minor version: ${bytes.elementAt(1)}');
    }
    return NpyVersion(major: bytes.elementAt(0), minor: bytes.elementAt(1));
  }

  List<int> toBytes() => [major, minor];

  /// Returns the number of bytes used to store the header length depending on the version.
  int get numberOfHeaderBytes => major == 1 ? 2 : 4;
}

class NpyHeader {
  final NpyDType dtype;
  final bool fortranOrder;
  final List<int> shape;

  const NpyHeader({
    required this.dtype,
    required this.fortranOrder,
    required this.shape,
  });

  factory NpyHeader.fromString(String headerString) {
    if (headerString.length < 2) throw const NpyInvalidHeaderException(message: 'Header string is too short.');

    final inputString = headerString.trim().substring(1, headerString.length - 1);
    final Map<String, dynamic> header = {};
    final entryPattern = RegExp(r"'([^']+)'\s*:\s*(.+?)(?=\s*,\s*'|$)", multiLine: true, dotAll: true);

    for (final match in entryPattern.allMatches(inputString)) {
      final key = match.group(1)!.trim();
      final value = match.group(2)!.trim();

      if (value == 'True') {
        header[key] = true;
      } else if (value == 'False') {
        header[key] = false;
      } else if (value.startsWith('(') && value.endsWith(')')) {
        final shapeString = value.substring(1, value.length - 1).trim();
        if (shapeString.isEmpty) {
          header[key] = <int>[];
        } else {
          header[key] =
              shapeString.split(',').where((s) => s.trim().isNotEmpty).map((s) => int.parse(s.trim())).toList();
        }
      } else if (RegExp(r"^\s*[0-9]+\s*$").hasMatch(value)) {
        header[key] = int.parse(value.trim());
      } else if (RegExp(r"^\s*[0-9.]+\s*$").hasMatch(value)) {
        header[key] = double.parse(value.trim());
      } else {
        header[key] = value.replaceAll("'", "").trim();
      }
    }

    final descr = header['descr'];
    final fortranOrder = header['fortran_order'];
    final shape = header['shape'];

    if (descr is! String) throw const NpyInvalidHeaderException(message: "Missing or invalid 'descr' field.");
    if (fortranOrder is! bool) {
      throw const NpyInvalidHeaderException(message: "Missing or invalid 'fortran_order' field.");
    }
    if (shape is! List<int>) throw const NpyInvalidHeaderException(message: "Missing or invalid 'shape' field.");

    return NpyHeader(
      dtype: NpyDType.fromString(descr),
      fortranOrder: fortranOrder,
      shape: shape,
    );
  }

  /// Returns the length of the header depending on the version and the given [bytes].
  static int getLength({required List<int> bytes, NpyVersion version = const NpyVersion()}) =>
      version.major == 1 ? littleEndian16ToInt(bytes) : littleEndian32ToInt(bytes);
}

/// Converts the given [bytes] to a 16-bit unsigned integer in little-endian byte order.
int littleEndian16ToInt(List<int> bytes) {
  assert(bytes.length == 2);
  final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
  return byteData.getUint16(0, Endian.little);
}

/// Converts the given [bytes] to a 32-bit unsigned integer in little-endian byte order.
int littleEndian32ToInt(List<int> bytes) {
  assert(bytes.length == 4);
  final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
  return byteData.getUint32(0, Endian.little);
}

class NpyDType {
  const NpyDType({
    required this.byteOrder,
    required this.kind,
    required this.itemsize,
  });

  final NpyByteOrder byteOrder;
  final NpyType kind;
  final int itemsize;

  factory NpyDType.fromString(String string) {
    if (string.length < 3) throw NpyInvalidDTypeException(message: "Invalid 'descr' field: '$string'");
    try {
      final byteOrder = NpyByteOrder.fromChar(string[0]);
      final kind = NpyType.fromChar(string[1]);
      final itemsize = int.parse(string.substring(2));
      return NpyDType(byteOrder: byteOrder, kind: kind, itemsize: itemsize);
    } catch (e) {
      throw NpyInvalidDTypeException(message: "Invalid 'descr' field: '$string': $e");
    }
  }

  @override
  String toString() => '${byteOrder.char}${kind.char}$itemsize';
}

enum NpyByteOrder {
  littleEndian('<'),
  bigEndian('>'),
  nativeEndian('='),
  none('|');

  const NpyByteOrder(this.char);

  final String char;

  factory NpyByteOrder.fromChar(String char) {
    return NpyByteOrder.values.firstWhere(
      (order) => order.char == char,
      orElse: () => throw NpyUnsupportedByteOrderException(message: 'Unsupported byte order: $char'),
    );
  }
}

enum NpyType {
  boolean('b'),
  int('i'),
  uint('u'),
  float('f'),
  complex('c'),
  string('S'),
  unicode('U'),
  voidType('V');

  const NpyType(this.char);

  final String char;

  factory NpyType.fromChar(String char) {
    return NpyType.values.firstWhere(
      (type) => type.char == char,
      orElse: () => throw NpyUnsupportedTypeException(message: 'Unsupported data type: $char'),
    );
  }
}
