import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:npy/src/np_exception.dart';

class NdArray<T> {
  const NdArray({
    required this.headerSection,
    required this.data,
  });

  final NpyHeaderSection headerSection;
  final List<T> data;

  factory NdArray.fromList(List<T> list, {NpyDType? dtype, bool? fortranOrder}) => NdArray<T>(
        headerSection: NpyHeaderSection.fromList(list, dtype: dtype, fortranOrder: fortranOrder),
        data: list,
      );

  T getElement(List<int> indices) => data[_getIndex(indices)];

  int _getIndex(List<int> indices) {
    assert(indices.length == headerSection.header.shape.length);
    int index = 0;
    int stride = 1;
    final shape = headerSection.header.shape;
    final order = headerSection.header.fortranOrder;

    for (int i = 0; i < indices.length; i++) {
      final idx = order ? i : indices.length - 1 - i;
      index += indices[idx] * stride;
      stride *= shape[idx];
    }
    return index;
  }

  List<int> get asBytes {
    final List<int> dataBytes = [];
    final dtype = headerSection.header.dtype;
    late final Endian endian;

    switch (dtype.endian) {
      case NpyEndian.little:
        endian = Endian.little;
      case NpyEndian.big:
        endian = Endian.big;
      case NpyEndian.native:
        endian = Endian.host;
      default:
        throw NpyUnsupportedEndianException(message: 'Unsupported endian: ${dtype.endian}');
    }

    for (final element in data) {
      final byteData = ByteData(dtype.itemSize);
      if (element is int) {
        switch (dtype.type) {
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
            throw NpyUnsupportedNpyTypeException(message: 'Unsupported NpyType: ${dtype.type}');
        }
      } else if (element is double) {
        switch (dtype.itemSize) {
          case 4:
            byteData.setFloat32(0, element, endian);
          case 8:
            byteData.setFloat64(0, element, endian);
          default:
            throw NpyUnsupportedDTypeException(message: 'Unsupported NpyType: ${dtype.type}');
        }
      } else {
        throw NpyUnsupportedTypeException(message: 'Unsupported NdArray type: $T');
      }

      dataBytes.addAll(Uint8List.fromList(byteData.buffer.asUint8List()));
    }

    return [...headerSection.asBytes, ...dataBytes];
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
    this.hasPassedMagicStringCheck = false,
    this.version,
    this.headerSize,
    this.header,
  });

  bool hasPassedMagicStringCheck;
  NpyVersion? version;
  int? headerSize;
  NpyHeader? header;

  void checkMagicString(List<int> bytes) {
    if (hasPassedMagicStringCheck || bytes.length < magicString.length) return;
    if (!const IterableEquality().equals(magicString.codeUnits, bytes.take(magicString.length))) {
      throw const NpyInvalidMagicStringException(message: 'Invalid magic string.');
    }
    hasPassedMagicStringCheck = true;
  }

  void getVersion(List<int> bytes) {
    if (version != null || bytes.length < magicString.length + NpyVersion.numberOfReservedBytes) return;
    version = NpyVersion.fromBytes(bytes.skip(magicString.length).take(NpyVersion.numberOfReservedBytes));
  }

  void getHeaderSize(List<int> bytes) {
    const bytesTaken = magicString.length + NpyVersion.numberOfReservedBytes;
    if (headerSize != null || version == null || bytes.length < bytesTaken + version!.numberOfHeaderBytes) return;
    final relevantBytes = bytes.skip(bytesTaken).take(version!.numberOfHeaderBytes).toList();
    headerSize = version!.major == 1 ? littleEndian16ToInt(relevantBytes) : littleEndian32ToInt(relevantBytes);
  }

  void getHeader(List<int> bytes) {
    if (header != null || version == null || headerSize == null) return;
    final bytesTaken = magicString.length + NpyVersion.numberOfReservedBytes + version!.numberOfHeaderBytes;
    if (bytes.length < bytesTaken + headerSize!) return;
    header = NpyHeader.fromString(String.fromCharCodes(bytes.skip(bytesTaken).take(headerSize!)));
  }

  bool get isNotReadyForData => header == null || headerSize == null || version == null || !hasPassedMagicStringCheck;
}

class NpyHeaderSection {
  const NpyHeaderSection({
    required this.version,
    required this.header,
    required this.headerSize,
    required this.paddingSize,
  });

  final NpyVersion version;
  final int headerSize;
  final NpyHeader header;
  final int paddingSize;

  factory NpyHeaderSection.fromList(List list, {NpyDType? dtype, bool? fortranOrder}) => NpyHeaderSection.fromHeader(
        NpyHeader.fromList(list, dtype: dtype, fortranOrder: fortranOrder),
      );

  factory NpyHeaderSection.buildPadding({
    required NpyVersion version,
    required int headerLength,
    required NpyHeader header,
  }) {
    final paddingSize = getPaddingSize(
      magicString.length +
          NpyVersion.numberOfReservedBytes +
          version.numberOfHeaderBytes +
          headerLength +
          _newLineOffset,
    );

    return NpyHeaderSection(
      version: version,
      headerSize: headerLength,
      header: header,
      paddingSize: paddingSize,
    );
  }

  factory NpyHeaderSection.fromHeader(NpyHeader header) {
    final headerSize = header.length;
    final firstVersionSizeWithoutPadding = magicString.length +
        NpyVersion.numberOfReservedBytes +
        NpyVersion.numberOfHeaderSizeBytesV1 +
        headerSize +
        _newLineOffset;
    final paddingSize = getPaddingSize(firstVersionSizeWithoutPadding);
    final version = NpyVersion.fromString(header.string, headerSize + paddingSize + _newLineInt);

    return NpyHeaderSection(
      version: version,
      headerSize: headerSize,
      header: header,
      paddingSize: paddingSize,
    );
  }

  /// Returns entire header section represented by a List of bytes that includes the magic string, the version, the
  /// number of bytes describing the header length, the header length, and the header, padded with spaces and terminated
  /// with a newline character to be a multiple of 64 bytes. It takes the header as a String and leaves it unchanged.
  List<int> get asBytes {
    final headerBytes = header.asBytes;
    final headerSize = headerBytes.length + paddingSize + _newLineOffset;

    return [
      ...magicString.codeUnits,
      ...version.asBytes,
      ...headerSizeBytes(headerSize),
      ...headerBytes,
      ...List.filled(paddingSize, _blankSpaceInt),
      _newLineInt,
    ];
  }

  /// Returns a list of bytes that encodes the [headerSize]. The list length depends on the major version.
  List<int> headerSizeBytes(int headerSize) {
    if (version.major == 1) {
      assert(headerSize <= NpyVersion.maxFirstVersionSize);
      return (ByteData(2)..setUint16(0, headerSize, Endian.little)).buffer.asUint8List();
    }

    assert(headerSize <= NpyVersion.maxHigherVersionSize);
    return (ByteData(4)..setUint32(0, headerSize, Endian.little)).buffer.asUint8List();
  }

  /// Returns the length of the entire header section.
  int get length => asBytes.length;
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
  static const numberOfHeaderSizeBytesV1 = 2;
  static const numberOfHeaderSizeBytesHigherVersions = 4;
  static const maxFirstVersionSize = 65535;
  static const maxHigherVersionSize = 4294967295;
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

  /// Returns a version instance depending on the given [string] and the total header size.
  factory NpyVersion.fromString(String string, int totalHeaderSize) {
    return NpyVersion(
      major: cannotBeAsciiEncoded(string)
          ? 3
          : totalHeaderSize <= maxFirstVersionSize
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
      major == 1 ? NpyVersion.numberOfHeaderSizeBytesV1 : NpyVersion.numberOfHeaderSizeBytesHigherVersions;
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

  factory NpyHeader.fromList(List list, {NpyDType? dtype, bool? fortranOrder, List<int> shape = const []}) {
    if (list.isEmpty) {
      return NpyHeader.buildString(
        dtype: dtype ??
            NpyDType.fromArgs(endian: NpyEndian.little, type: NpyType.float, itemSize: NpyDType._defaultItemSize),
        fortranOrder: fortranOrder ?? false,
        shape: shape.isEmpty ? shape : [...shape, list.length],
      );
    }

    final updatedShape = [...shape, list.length];
    late final NpyType obtainedType;
    final firstElement = list.first;

    if (firstElement is int) {
      obtainedType = dtype?.type == NpyType.uint ? NpyType.uint : NpyType.int;
    } else if (firstElement is double) {
      obtainedType = NpyType.float;
    } else if (firstElement is List) {
      return NpyHeader.fromList(
        list.first as List,
        dtype: dtype,
        fortranOrder: fortranOrder,
        shape: updatedShape,
      );
    } else {
      throw NpyUnsupportedTypeException(message: 'Unsupported input type: ${firstElement.runtimeType}');
    }

    return NpyHeader.buildString(
      dtype: NpyDType.fromArgs(
        endian: dtype?.endian ?? NpyEndian.little,
        type: obtainedType,
        itemSize: dtype?.itemSize ?? NpyDType._defaultItemSize,
      ),
      fortranOrder: fortranOrder ?? false,
      shape: updatedShape,
    );
  }

  /// Returns the header string as a List<int> of bytes.
  List<int> get asBytes => utf8.encode(string);

  /// Returns the length of the header string.
  int get length => asBytes.length;
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
  const NpyDType.float64({NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.float,
        itemSize = 8;

  const NpyDType.float32({NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.float,
        itemSize = 4;

  const NpyDType.int64({NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.int,
        itemSize = 8;

  const NpyDType.int32({NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.int,
        itemSize = 4;

  const NpyDType.int16({NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.int,
        itemSize = 2;

  const NpyDType.int8({NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.int,
        itemSize = 1;

  const NpyDType.uint64({NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.uint,
        itemSize = 8;

  const NpyDType.uint32({NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.uint,
        itemSize = 4;

  const NpyDType.uint16({NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.uint,
        itemSize = 2;

  const NpyDType.uint8({NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.uint,
        itemSize = 1;

  const NpyDType.string({required this.itemSize, NpyEndian? endian})
      : endian = endian ?? NpyEndian.native,
        type = NpyType.string;

  final NpyEndian endian;
  final NpyType type;
  final int itemSize;

  static const _defaultItemSize = 8;

  factory NpyDType.fromArgs({required NpyType type, required int itemSize, NpyEndian? endian}) {
    switch (type) {
      case NpyType.float:
        switch (itemSize) {
          case 8:
            return NpyDType.float64(endian: endian);
          case 4:
            return NpyDType.float32(endian: endian);
          default:
            throw NpyUnsupportedDTypeException(message: 'Unsupported float item size: $itemSize');
        }
      case NpyType.int:
        switch (itemSize) {
          case 8:
            return NpyDType.int64(endian: endian);
          case 4:
            return NpyDType.int32(endian: endian);
          case 2:
            return NpyDType.int16(endian: endian);
          case 1:
            return NpyDType.int8(endian: endian);
          default:
            throw NpyUnsupportedDTypeException(message: 'Unsupported int item size: $itemSize');
        }
      case NpyType.uint:
        switch (itemSize) {
          case 8:
            return NpyDType.uint64(endian: endian);
          case 4:
            return NpyDType.uint32(endian: endian);
          case 2:
            return NpyDType.uint16(endian: endian);
          case 1:
            return NpyDType.uint8(endian: endian);
          default:
            throw NpyUnsupportedDTypeException(message: 'Unsupported uint item size: $itemSize');
        }
      case NpyType.string:
        return NpyDType.string(itemSize: itemSize, endian: endian);
      default:
        throw NpyUnsupportedNpyTypeException(message: 'Unsupported NpyType: $type');
    }
  }

  factory NpyDType.fromString(String string) {
    if (string.length < 3) throw NpyInvalidDTypeException(message: "'descr' field has insufficient length: '$string'");

    try {
      final endian = NpyEndian.fromChar(string[0]);
      final type = NpyType.fromChar(string[1]);
      final itemSize = int.parse(string.substring(2));
      return NpyDType.fromArgs(endian: endian, type: type, itemSize: itemSize);
    } catch (e) {
      throw NpyInvalidDTypeException(message: "Invalid 'descr' field: '$string': $e");
    }
  }

  @override
  String toString() => '${endian.char}${type.chars.first}$itemSize';
}

enum NpyEndian {
  little('<'),
  big('>'),
  native('='),
  none('|');

  const NpyEndian(this.char);

  final String char;

  factory NpyEndian.fromChar(String char) {
    assert(char.length == 1);
    return NpyEndian.values.firstWhere(
      (order) => order.char == char,
      orElse: () => throw NpyUnsupportedEndianException(message: 'Unsupported endian: $char'),
    );
  }
}

enum NpyType {
  boolean(['?']),
  byte(['b']),
  uByte(['B']),
  int(['i']),
  uint(['u']),
  float(['f']),
  complex(['c']),
  timeDelta(['m']),
  dateTime(['M']),
  object(['O']),
  string(['S', 'a']),
  unicode(['U']),
  voidType(['V']);

  const NpyType(this.chars);

  final List<String> chars;

  factory NpyType.fromChar(String char) {
    assert(char.length == 1);
    return NpyType.values.firstWhere(
      (type) => type.matches(char),
      orElse: () => throw NpyUnsupportedNpyTypeException(message: 'Unsupported list type: $char'),
    );
  }

  bool matches(String char) => chars.contains(char);
}
