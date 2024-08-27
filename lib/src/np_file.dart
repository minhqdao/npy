import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:npy/src/np_exception.dart';

class NDArray<T> {
  const NDArray({
    required this.header,
    this.data = const [],
  });

  final NpyHeader header;
  final List<T> data;

  T getElement(List<int> indices) => data[_getIndex(indices)];

  int _getIndex(List<int> indices) {
    int index = 0;
    int stride = 1;
    final shape = header.shape;
    final order = header.fortranOrder;

    for (int i = 0; i < indices.length; i++) {
      final idx = order ? i : indices.length - 1 - i;
      index += indices[idx] * stride;
      stride *= shape[idx];
    }
    return index;
  }
}

// class NpzFile {
//   const NpzFile({
//     required this.files,
//   });

//   final Map<String, NDArray> files;
// }

class NpyHeaderSection {
  NpyHeaderSection({
    this.isMagicStringChecked = false,
    this.version,
    this.headerLength,
    this.header,
  });

  factory NpyHeaderSection.fromString(String headerString) =>
      NpyHeaderSection(version: NpyVersion.fromString(headerString), header: NpyHeader.fromString(headerString));

  bool isMagicStringChecked;
  NpyVersion? version;
  int? headerLength;
  NpyHeader? header;

  void checkMagicString(List<int> bytes) {
    if (isMagicStringChecked || bytes.length < magicString.length) return;
    if (!const IterableEquality().equals(magicString.codeUnits, bytes.take(magicString.length))) {
      throw const NpyInvalidMagicStringException(message: 'Invalid magic string.');
    }
    isMagicStringChecked = true;
  }

  void parseVersion(List<int> bytes) {
    if (version != null || bytes.length < magicString.length + numberOfVersionBytes) return;
    version = NpyVersion.fromBytes(bytes.skip(magicString.length).take(numberOfVersionBytes));
  }

  void parseHeaderLength(List<int> bytes) {
    const bytesTaken = magicString.length + numberOfVersionBytes;
    if (headerLength != null || version == null || bytes.length < bytesTaken + numberOfHeaderBytes) return;
    headerLength = getHeaderLength(bytes.skip(bytesTaken).take(numberOfHeaderBytes).toList());
  }

  void parseHeader(List<int> bytes) {
    final bytesTaken = magicString.length + numberOfVersionBytes + numberOfHeaderBytes;
    if (header != null || version == null || headerLength == null || bytes.length < bytesTaken + headerLength!) return;
    header = NpyHeader.fromString(String.fromCharCodes(bytes.skip(bytesTaken).take(headerLength!)));
  }

  /// The number of bytes reserved in the header section to describe the version.
  static const numberOfVersionBytes = 2;

  /// Returns the length of the header depending on the given [bytes].
  int getHeaderLength(List<int> bytes) {
    if (version == null) {
      throw const NpyParseOrderException(message: 'Version must be set before parsing header length.');
    }
    return version!.major == 1 ? littleEndian16ToInt(bytes) : littleEndian32ToInt(bytes);
  }

  /// Returns the number of bytes used to store the header length depending on the major version.
  int get numberOfHeaderBytes {
    if (version == null) {
      throw const NpyParseOrderException(message: 'Version must be set before getting the number of header bytes.');
    }
    return version!.major == 1 ? 2 : 4;
  }

  /// Returns entire header section represented by a List of bytes that includes the magic string, the version,
  /// the number of bytes describing the header length, the header length, and the header, padded with spaces and
  /// terminated with a newline character to be a multiple of 64 bytes. It takes the header
  /// as a String and leaves it unchanged.
  List<int> get asBytes {
    if (version == null) {
      throw const NpyParseOrderException(message: 'Version must be set before header section can be obtained.');
    } else if (header == null) {
      throw const NpyParseOrderException(message: 'Header must be set before header section can be obtained.');
    }

    final headerBytes = header!.asBytes;
    final sizeWithoutPadding =
        magicString.length + numberOfVersionBytes + numberOfHeaderBytes + headerBytes.length + _newLineOffset;
    final paddingSize = (64 - (sizeWithoutPadding % 64)) % 64;
    final headerSize = headerBytes.length + paddingSize + _newLineOffset;

    List<int> headerSizeBytes;

    if (version!.major == 1) {
      assert(headerSize < 65536);
      headerSizeBytes = [headerSize & 0xFF, (headerSize >> 8) & 0xFF];
    } else {
      headerSizeBytes = [
        headerSize & 0xFF,
        (headerSize >> 8) & 0xFF,
        (headerSize >> 16) & 0xFF,
        (headerSize >> 24) & 0xFF,
      ];
    }

    return [
      ...magicString.codeUnits,
      ...version!.asBytes,
      ...headerSizeBytes,
      ...header!.asBytes,
      ...List.filled(paddingSize, _blankSpaceInt),
      _newLineInt,
    ];
  }
}

class NpyVersion {
  const NpyVersion({
    this.major = 1,
    this.minor = 0,
  });

  final int major;
  final int minor;
  static const _supportedMajorVersions = {1, 2, 3};
  static const _supportedMinorVersions = {0};

  factory NpyVersion.fromBytes(Iterable<int> bytes) {
    assert(bytes.length == NpyHeaderSection.numberOfVersionBytes);
    if (!_supportedMajorVersions.contains(bytes.elementAt(0))) {
      throw NpyUnsupportedVersionException(message: 'Unsupported major version: ${bytes.elementAt(0)}');
    }
    if (!_supportedMinorVersions.contains(bytes.elementAt(1))) {
      throw NpyUnsupportedVersionException(message: 'Unsupported minor version: ${bytes.elementAt(1)}');
    }
    return NpyVersion(major: bytes.elementAt(0), minor: bytes.elementAt(1));
  }

  /// Returns a version instance depending on the given [string].
  factory NpyVersion.fromString(String string) => NpyVersion(
        major: !_canBeAsciiEncoded(string)
            ? 3
            : string.length < 65536
                ? 1
                : 2,
      );

  /// Whether the given [string] can be ASCII encoded.
  static bool _canBeAsciiEncoded(String string) {
    for (int i = 0; i < string.length; i++) {
      if (string.codeUnitAt(i) > 127) {
        return false;
      }
    }
    return true;
  }

  /// Returns the version as a List<int> of bytes.
  List<int> get asBytes => [major, minor];
}

class NpyHeader {
  const NpyHeader({
    required this.dtype,
    required this.fortranOrder,
    required this.shape,
    required this.string,
  });

  final NpyDType dtype;
  final bool fortranOrder;
  final List<int> shape;
  final String string;

  factory NpyHeader.fromString(String headerString) {
    if (headerString.length < 2) throw const NpyInvalidHeaderException(message: 'Header string is too short.');

    final inputString = headerString.trim().substring(1, headerString.length - 1);
    final Map<String, dynamic> header = {};
    final entryPattern = RegExp(r"'([^']+)'\s*:\s*(.+?)(?=\s*,\s*'|$|\s*,\s*$)", multiLine: true, dotAll: true);

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
      string: headerString,
    );
  }

  /// Returns the header string as a List<int> of bytes.
  List<int> get asBytes => utf8.encode(string);
}

/// The ASCII code for a space character.
const _blankSpaceInt = 32;

/// The ASCII code for a newline character.
const _newLineInt = 10;

/// The header section is terminated with a single byte that is a newline character.
const _newLineOffset = 1;

/// Marks the beginning of an NPY file.
const magicString = '\x93NUMPY';

/// Converts the given [bytes] to a 16-bit unsigned integer in little-endian byte order.
int littleEndian16ToInt(List<int> bytes) {
  assert(bytes.length == 2);
  return ByteData.sublistView(Uint8List.fromList(bytes)).getUint16(0, Endian.little);
}

/// Converts the given [bytes] to a 32-bit unsigned integer in little-endian byte order.
int littleEndian32ToInt(List<int> bytes) {
  assert(bytes.length == 4);
  return ByteData.sublistView(Uint8List.fromList(bytes)).getUint32(0, Endian.little);
}

class NpyDType {
  const NpyDType({
    required this.byteOrder,
    required this.kind,
    required this.itemSize,
  });

  final NpyByteOrder byteOrder;
  final NpyType kind;
  final int itemSize;

  factory NpyDType.fromString(String string) {
    if (string.length < 3) throw NpyInvalidDTypeException(message: "Invalid 'descr' field: '$string'");

    try {
      final byteOrder = NpyByteOrder.fromChar(string[0]);
      final kind = NpyType.fromChar(string[1]);
      final itemSize = int.parse(string.substring(2));
      return NpyDType(byteOrder: byteOrder, kind: kind, itemSize: itemSize);
    } catch (e) {
      throw NpyInvalidDTypeException(message: "Invalid 'descr' field: '$string': $e");
    }
  }

  @override
  String toString() => '${byteOrder.char}${kind.char}$itemSize';
}

enum NpyByteOrder {
  littleEndian('<'),
  bigEndian('>'),
  nativeEndian('='),
  none('|');

  const NpyByteOrder(this.char);

  final String char;

  factory NpyByteOrder.fromChar(String char) => NpyByteOrder.values.firstWhere(
        (order) => order.char == char,
        orElse: () => throw NpyUnsupportedByteOrderException(message: 'Unsupported byte order: $char'),
      );
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

  factory NpyType.fromChar(String char) => NpyType.values.firstWhere(
        (type) => type.char == char,
        orElse: () => throw NpyUnsupportedNpyTypeException(message: 'Unsupported data type: $char'),
      );
}
