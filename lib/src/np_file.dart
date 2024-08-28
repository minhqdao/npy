import 'dart:convert';
// import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:npy/src/np_exception.dart';

class NdArray<T> {
  const NdArray({
    required this.header,
    this.data = const [],
  });

  final NpyHeader header;
  final List<T> data;

  factory NdArray.fromList(List<T> data, {NpyEndian? endian, bool? fortranOrder}) =>
      NdArray<T>(header: NpyHeader<T>.fromList(data, endian: endian, fortranOrder: fortranOrder), data: data);

  T getElement(List<int> indices) => data[_getIndex(indices)];

  int _getIndex(List<int> indices) {
    assert(indices.length == header.shape.length);
    print('hi');
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

  List<int> get asBytes {
    final List<int> dataBytes = [];
    final dtype = header.dtype;
    late final Endian endian;

    switch (dtype.endian) {
      case NpyEndian.little:
        endian = Endian.little;
      case NpyEndian.big:
        endian = Endian.big;
      default:
        throw NpyUnsupportedEndianException(message: 'Unsupported endian: ${dtype.endian}');
    }

    for (final element in data) {
      final byteData = ByteData(dtype.itemSize);
      if (element is int) {
        switch (dtype.kind) {
          case NpyType.int:
            switch (dtype.itemSize) {
              case 1:
                byteData.setInt8(0, element);
              case 2:
                byteData.setInt16(0, element, endian);
              case 4:
                byteData.setInt32(0, element, endian);
              case 8:
                byteData.setInt64(0, element, endian);
              default:
                throw NpyUnsupportedDTypeException(message: 'Unsupported item size: ${dtype.itemSize}');
            }
          case NpyType.uint:
            switch (dtype.itemSize) {
              case 1:
                byteData.setUint8(0, element);
              case 2:
                byteData.setUint16(0, element, endian);
              case 4:
                byteData.setUint32(0, element, endian);
              case 8:
                byteData.setUint64(0, element, endian);
              default:
                throw NpyUnsupportedDTypeException(message: 'Unsupported item size: ${dtype.itemSize}');
            }
          default:
            throw NpyUnsupportedNpyTypeException(message: 'Unsupported NpyType: ${dtype.kind}');
        }
      } else if (element is double) {
        switch (dtype.itemSize) {
          case 4:
            byteData.setFloat32(0, element, endian);
          case 8:
            byteData.setFloat64(0, element, endian);
          default:
            throw NpyUnsupportedDTypeException(message: 'Unsupported NpyType: ${dtype.kind}');
        }
      } else {
        throw NpyUnsupportedTypeException(message: 'Unsupported NdArray type: $T');
      }

      dataBytes.addAll(Uint8List.fromList(byteData.buffer.asUint8List()));
    }

    return [...header.buildSection(), ...dataBytes];
  }
}

// class NpzFile {
//   const NpzFile({
//     required this.files,
//   });

//   final Map<String, NdArray> files;
// }

class NpyParser<T> {
  NpyParser({
    this.isMagicStringChecked = false,
    this.version,
    this.headerLength,
    this.header,
  });

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

  void getVersion(List<int> bytes) {
    if (version != null || bytes.length < magicString.length + NpyVersion.numberOfReservedBytes) return;
    version = NpyVersion.fromBytes(bytes.skip(magicString.length).take(NpyVersion.numberOfReservedBytes));
  }

  void getHeaderLength(List<int> bytes) {
    const bytesTaken = magicString.length + NpyVersion.numberOfReservedBytes;
    if (headerLength != null || version == null || bytes.length < bytesTaken + version!.numberOfHeaderBytes) return;
    final relevantBytes = bytes.skip(bytesTaken).take(version!.numberOfHeaderBytes).toList();
    headerLength = version!.major == 1 ? littleEndian16ToInt(relevantBytes) : littleEndian32ToInt(relevantBytes);
  }

  void getHeader(List<int> bytes) {
    if (header != null || version == null || headerLength == null) return;
    final bytesTaken = magicString.length + NpyVersion.numberOfReservedBytes + version!.numberOfHeaderBytes;
    if (bytes.length < bytesTaken + headerLength!) return;
    header = NpyHeader.fromString(String.fromCharCodes(bytes.skip(bytesTaken).take(headerLength!)));
  }
}

/// Returns the number of padding bytes needed to make the given [size] a multiple of 64.
int getPaddingSize(int size) => (64 - (size % 64)) % 64;

class NpyVersion {
  const NpyVersion({
    this.major = 1,
    this.minor = 0,
  });

  final int major;
  final int minor;

  /// The number of bytes reserved in the header section to describe the version.
  static const numberOfReservedBytes = 2;
  static const numberOfHeaderSizeBytesFirstVersion = 2;
  static const numberOfHeaderSizeBytesLaterVersions = 4;
  static const maxSizeFirstVersion = 65536;
  static const lastAsciiCodeUnit = 127;
  static const _supportedMajorVersions = {1, 2, 3};
  static const _supportedMinorVersions = {0};

  factory NpyVersion.fromBytes(Iterable<int> bytes) {
    assert(bytes.length == NpyVersion.numberOfReservedBytes);
    if (!_supportedMajorVersions.contains(bytes.elementAt(0))) {
      throw NpyUnsupportedVersionException(message: 'Unsupported major version: ${bytes.elementAt(0)}');
    }
    if (!_supportedMinorVersions.contains(bytes.elementAt(1))) {
      throw NpyUnsupportedVersionException(message: 'Unsupported minor version: ${bytes.elementAt(1)}');
    }
    return NpyVersion(major: bytes.elementAt(0), minor: bytes.elementAt(1));
  }

  /// Returns a version instance depending on the given [string].
  factory NpyVersion.fromString(String string) {
    final firstVersionSizeWithoutPadding = magicString.length +
        NpyVersion.numberOfReservedBytes +
        NpyVersion.numberOfHeaderSizeBytesFirstVersion +
        string.length +
        _newLineOffset;
    return NpyVersion(
      major: cannotBeAsciiEncoded(string)
          ? 3
          : firstVersionSizeWithoutPadding + getPaddingSize(firstVersionSizeWithoutPadding) < maxSizeFirstVersion
              ? 1
              : 2,
    );
  }

  /// True if [string] cannot be ASCII encoded.
  static bool cannotBeAsciiEncoded(String string) => string.codeUnits.any((codeUnit) => codeUnit > lastAsciiCodeUnit);

  /// Returns the version as a List<int> of bytes.
  List<int> get asBytes => [major, minor];

  /// Returns the number of bytes used to store the header length depending on the major version.
  int get numberOfHeaderBytes =>
      major == 1 ? NpyVersion.numberOfHeaderSizeBytesFirstVersion : NpyVersion.numberOfHeaderSizeBytesLaterVersions;
}

class NpyHeader<T> {
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

  factory NpyHeader.buildString({required NpyDType dtype, required bool fortranOrder, required List<int> shape}) {
    final shapeString = shape.isEmpty
        ? '()'
        : shape.length == 1
            ? '(${shape.first},)'
            : '(${shape.join(', ')})';
    final string = "{'descr': '$dtype', 'fortran_order': ${fortranOrder ? 'True' : 'False'}, 'shape': $shapeString, }";
    return NpyHeader(dtype: dtype, fortranOrder: fortranOrder, shape: shape, string: string);
  }

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

  factory NpyHeader.fromList(List<T> data, {NpyEndian? endian, bool? fortranOrder}) {
    if (data.isEmpty) {
      return NpyHeader.buildString(
        dtype: NpyDType(endian: endian ?? NpyEndian.little, kind: NpyType.float, itemSize: 8),
        fortranOrder: fortranOrder ?? false,
        shape: [],
      );
    }

    late final NpyType kind;
    if (T == int) {
      kind = NpyType.int;
    } else if (T == double) {
      kind = NpyType.float;
    } else {
      throw NpyUnsupportedTypeException(message: 'Unsupported input type: $T');
    }

    return NpyHeader.buildString(
      dtype: NpyDType(endian: endian ?? NpyEndian.little, kind: kind, itemSize: 8),
      fortranOrder: fortranOrder ?? false,
      shape: [data.length],
    );
  }

  /// Returns the header string as a List<int> of bytes.
  List<int> get asBytes => utf8.encode(string);

  /// Returns entire header section represented by a List of bytes that includes the magic string, the version, the
  /// number of bytes describing the header length, the header length, and the header, padded with spaces and terminated
  /// with a newline character to be a multiple of 64 bytes. It takes the header as a String and leaves it unchanged.
  List<int> buildSection() {
    final version = NpyVersion.fromString(string);
    final headerBytes = asBytes;
    final sizeWithoutPadding = magicString.length +
        NpyVersion.numberOfReservedBytes +
        version.numberOfHeaderBytes +
        headerBytes.length +
        _newLineOffset;
    final paddingSize = getPaddingSize(sizeWithoutPadding);
    final headerSize = headerBytes.length + paddingSize + _newLineOffset;

    List<int> headerSizeBytes;

    if (version.major == 1) {
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
      ...version.asBytes,
      ...headerSizeBytes,
      ...headerBytes,
      ...List.filled(paddingSize, _blankSpaceInt),
      _newLineInt,
    ];
  }
}

/// The ASCII code for a space character.
const _blankSpaceInt = 32;

/// The ASCII code for a newline character.
const _newLineInt = 10;

/// The header section is terminated with a single byte that is a newline character.
const _newLineOffset = 1;

/// Marks the beginning of an NPY file.
const magicString = '\x93NUMPY';

/// The supported input types for the NdArray class.
const supportedInputTypes = {int, double};

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
    required this.endian,
    required this.kind,
    required this.itemSize,
  });

  final NpyEndian endian;
  final NpyType kind;
  final int itemSize;

  factory NpyDType.fromString(String string) {
    if (string.length < 3) throw NpyInvalidDTypeException(message: "Invalid 'descr' field: '$string'");

    try {
      final endian = NpyEndian.fromChar(string[0]);
      final kind = NpyType.fromChar(string[1]);
      final itemSize = int.parse(string.substring(2));
      return NpyDType(endian: endian, kind: kind, itemSize: itemSize);
    } catch (e) {
      throw NpyInvalidDTypeException(message: "Invalid 'descr' field: '$string': $e");
    }
  }

  @override
  String toString() => '${endian.char}${kind.char}$itemSize';
}

enum NpyEndian {
  little('<'),
  big('>'),
  native('='),
  none('|');

  const NpyEndian(this.char);

  final String char;

  factory NpyEndian.fromChar(String char) => NpyEndian.values.firstWhere(
        (order) => order.char == char,
        orElse: () => throw NpyUnsupportedEndianException(message: 'Unsupported endian: $char'),
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
