import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:npy/src/np_exception.dart';

class NdArray<T> {
  const NdArray({
    required this.headerSection,
    required this.data,
  });

  final NpyHeaderSection headerSection;
  final List data;

  factory NdArray.fromList(List list, {NpyDType? dtype, NpyEndian? endian, bool? fortranOrder}) => NdArray<T>(
        headerSection: NpyHeaderSection.fromList(list, dtype: dtype, endian: endian, fortranOrder: fortranOrder),
        data: list,
      );

  List<int> get asBytes => [...headerSection.asBytes, ...dataBytes];

  List<int> get dataBytes {
    final List<int> bytes = [];
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
        if (dtype.itemSize != 1) {
          throw const NpyUnsupportedEndianException(message: 'Endian must be specified for item size > 1.');
        }
    }

    final flattenedData = headerSection.header.fortranOrder
        ? flattenFortranOrder<T>(data, shape: headerSection.header.shape)
        : flattenCOrder<T>(data);

    for (final element in flattenedData) {
      final byteData = ByteData(dtype.itemSize);
      if (element is int) {
        switch (dtype.type) {
          case NpyType.int:
            switch (dtype.itemSize) {
              case 8:
                byteData.setInt64(0, element, endian);
              case 4:
                byteData.setInt32(0, element, endian);
              case 2:
                byteData.setInt16(0, element, endian);
              case 1:
                byteData.setInt8(0, element);
              default:
                throw NpyUnsupportedDTypeException(message: 'Unsupported item size: ${dtype.itemSize}');
            }
          case NpyType.uint:
            switch (dtype.itemSize) {
              case 8:
                byteData.setUint64(0, element, endian);
              case 4:
                byteData.setUint32(0, element, endian);
              case 2:
                byteData.setUint16(0, element, endian);
              case 1:
                byteData.setUint8(0, element);
              default:
                throw NpyUnsupportedDTypeException(message: 'Unsupported item size: ${dtype.itemSize}');
            }
          default:
            throw NpyUnsupportedNpyTypeException(message: 'Unsupported NpyType: ${dtype.type}');
        }
      } else if (element is double) {
        switch (dtype.itemSize) {
          case 8:
            byteData.setFloat64(0, element, endian);
          case 4:
            byteData.setFloat32(0, element, endian);
          default:
            throw NpyUnsupportedDTypeException(message: 'Unsupported NpyType: ${dtype.type}');
        }
      } else if (element is bool) {
        byteData.setUint8(0, element ? 1 : 0);
      } else {
        throw NpyUnsupportedTypeException(message: 'Unsupported NdArray type: ${element.runtimeType}');
      }
      bytes.addAll(Uint8List.fromList(byteData.buffer.asUint8List()));
    }

    return bytes;
  }
}

List<T> flattenCOrder<T>(List list) {
  final result = <T>[];
  for (final element in list) {
    element is List ? result.addAll(flattenCOrder<T>(element)) : result.add(element as T);
  }
  return result;
}

List<T> flattenFortranOrder<T>(List list, {required List<int> shape}) {
  final result = <T>[];
  if (shape.isNotEmpty) {
    _flattenFortranOrderRecursive<T>(
      list,
      shape,
      List.filled(shape.length, 0),
      shape.length - 1,
      (item) => result.add(item),
    );
  }
  return result;
}

void _flattenFortranOrderRecursive<T>(
  List list,
  List<int> shape,
  List<int> indices,
  int depth,
  void Function(T) addItem,
) {
  if (depth == 0) {
    for (int i = 0; i < shape[depth]; i++) {
      indices[depth] = i;
      addItem(_getNestedItem<T>(list, indices));
    }
  } else {
    for (int i = 0; i < shape[depth]; i++) {
      indices[depth] = i;
      _flattenFortranOrderRecursive<T>(list, shape, indices, depth - 1, addItem);
    }
  }
}

T _getNestedItem<T>(List list, List<int> indices) => _getNestedItemRecursive<T>(list, indices, 0);

T _getNestedItemRecursive<T>(List list, List<int> indices, int depth) => depth == indices.length - 1
    ? list[indices[depth]] as T
    : _getNestedItemRecursive<T>(list[indices[depth]] as List, indices, depth + 1);

// class NpzFile {
//   const NpzFile({
//     required this.files,
//   });

//   final Map<String, NdArray> files;
// }

class NpyParser<T> {
  NpyParser({
    bool hasPassedMagicStringCheck = false,
    NpyVersion? version,
    int? headerSize,
    NpyHeader? header,
  })  : _hasPassedMagicStringCheck = hasPassedMagicStringCheck,
        _version = version,
        _headerSize = headerSize,
        _header = header;

  bool _hasPassedMagicStringCheck;
  NpyVersion? _version;
  int? _headerSize;
  NpyHeader? _header;

  bool get hasPassedMagicStringCheck => _hasPassedMagicStringCheck;
  NpyVersion? get version => _version;
  int? get headerSize => _headerSize;
  NpyHeader? get header => _header;

  NpyHeaderSection? _headerSection;
  List _data = [];
  bool _isCompleted = false;
  int _dataOffset = 0;
  int _elementsRead = 0;

  NpyHeaderSection? get headerSection => _headerSection;
  List get data => _data;
  bool get isCompleted => _isCompleted;

  void checkMagicString(List<int> buffer) {
    if (_hasPassedMagicStringCheck || buffer.length < magicString.length) return;
    for (int i = 0; i < magicString.length; i++) {
      if (magicString.codeUnitAt(i) != buffer[i]) throw const NpyParseException(message: 'Invalid magic string.');
    }
    _hasPassedMagicStringCheck = true;
  }

  void getVersion(List<int> buffer) {
    if (_version != null || buffer.length < magicString.length + NpyVersion.numberOfReservedBytes) return;
    _version = NpyVersion.fromBytes(buffer.skip(magicString.length).take(NpyVersion.numberOfReservedBytes));
  }

  void getHeaderSize(List<int> buffer) {
    const bytesTaken = magicString.length + NpyVersion.numberOfReservedBytes;
    if (_headerSize != null || _version == null || buffer.length < bytesTaken + _version!.numberOfHeaderBytes) return;
    final relevantBytes = buffer.skip(bytesTaken).take(_version!.numberOfHeaderBytes).toList();
    _headerSize = _version!.major == 1 ? littleEndian16ToInt(relevantBytes) : littleEndian32ToInt(relevantBytes);
  }

  void getHeader(List<int> buffer) {
    if (_header != null || _version == null || _headerSize == null) return;
    final bytesTaken = magicString.length + NpyVersion.numberOfReservedBytes + _version!.numberOfHeaderBytes;
    if (buffer.length < bytesTaken + _headerSize!) return;
    _header = NpyHeader.fromBytes(buffer.skip(bytesTaken).take(_headerSize!).toList());
  }

  void buildHeaderSection() {
    if (_headerSection != null || _header == null || _headerSize == null || _version == null) return;
    _headerSection = NpyHeaderSection(version: _version!, headerSize: _headerSize!, header: _header!);
  }

  void getData(List<int> buffer) {
    if (_headerSection == null ||
        _header == null ||
        _headerSize == null ||
        _version == null ||
        !_hasPassedMagicStringCheck) {
      return;
    }

    if (_header!.shape.isEmpty) {
      _data = const [];
      _isCompleted = true;
      return;
    }

    final itemSize = _header!.dtype.itemSize;
    _dataOffset = _headerSection!.size + _elementsRead * itemSize;
    final totalElements = _header!.shape.reduce((a, b) => a * b);
    final remainingElements = totalElements - _elementsRead;
    final elementsInBuffer = (buffer.length - _dataOffset) ~/ itemSize;
    final elementsToProcess = min(remainingElements, elementsInBuffer);

    final newData = parseDataBytes<T>(buffer.sublist(_dataOffset, _dataOffset + elementsToProcess * itemSize), header!);

    _data.addAll(newData);
    _elementsRead += elementsToProcess;

    if (_elementsRead == totalElements) {
      _isCompleted = true;
      return;
    }

    _dataOffset += elementsToProcess * itemSize;
  }
}

/// Parse the data bytes according to the [header] metadata and return a single- or multidimensional [List] of values.
List parseDataBytes<T>(List<int> bytes, NpyHeader header) {
  final dtype = header.dtype;
  final numberOfElements = bytes.length ~/ dtype.itemSize;

  late final List result;
  switch (dtype.type) {
    case NpyType.float:
      result = List.filled(numberOfElements, .0 as T);
    case NpyType.int:
    case NpyType.uint:
      result = List.filled(numberOfElements, 0 as T);
    case NpyType.boolean:
      result = List.filled(numberOfElements, false as T);
    default:
      throw NpyUnsupportedDTypeException(message: 'Unsupported dtype: $dtype');
  }

  late final Endian endian;
  switch (dtype.endian) {
    case NpyEndian.little:
      endian = Endian.little;
    case NpyEndian.big:
      endian = Endian.big;
    case NpyEndian.native:
      endian = Endian.host;
    default:
      if (dtype.itemSize != 1) {
        throw const NpyUnsupportedEndianException(message: 'Endian must be specified for item size > 1.');
      }
  }

  final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);

  for (int i = 0; i < numberOfElements; i++) {
    switch (dtype.type) {
      case NpyType.float:
        switch (dtype.itemSize) {
          case 8:
            result[i] = byteData.getFloat64(i * 8, endian) as T;
          case 4:
            result[i] = byteData.getFloat32(i * 4, endian) as T;
          default:
            throw NpyUnsupportedDTypeException(message: 'Unsupported item size: ${dtype.itemSize}');
        }
      case NpyType.int:
        switch (dtype.itemSize) {
          case 8:
            result[i] = byteData.getInt64(i * 8, endian) as T;
          case 4:
            result[i] = byteData.getInt32(i * 4, endian) as T;
          case 2:
            result[i] = byteData.getInt16(i * 2, endian) as T;
          case 1:
            result[i] = byteData.getInt8(i) as T;
          default:
            throw NpyUnsupportedDTypeException(message: 'Unsupported item size: ${dtype.itemSize}');
        }
      case NpyType.uint:
        switch (dtype.itemSize) {
          case 8:
            result[i] = byteData.getUint64(i * 8, endian) as T;
          case 4:
            result[i] = byteData.getUint32(i * 4, endian) as T;
          case 2:
            result[i] = byteData.getUint16(i * 2, endian) as T;
          case 1:
            result[i] = byteData.getUint8(i) as T;
          default:
            throw NpyUnsupportedDTypeException(message: 'Unsupported item size: ${dtype.itemSize}');
        }
      case NpyType.boolean:
        result[i] = (byteData.getUint8(i) == 1) as T;
      default:
        throw NpyUnsupportedDTypeException(message: 'Unsupported dtype: $dtype');
    }
  }

  return reshape(result, header.shape, fortranOrder: header.fortranOrder);
}

/// Reshape a one-dimensional [List] according to the given [shape] and order (C or Fortran).
List<dynamic> reshape<T>(List<T> oneDimensionalList, List<int> shape, {bool fortranOrder = false}) {
  if (oneDimensionalList.isEmpty) return const [];
  if (shape.isEmpty) throw const NpyParseException(message: 'Shape must not be empty.');
  if (oneDimensionalList.length != shape.reduce((a, b) => a * b)) {
    throw const NpyParseException(
      message: 'The total number of elements does not equal the product of the shape dimensions.',
    );
  }

  if (shape.length == 1) return oneDimensionalList;

  int getIndex(List<int> indices) {
    int index = 0;
    int stride = 1;
    if (fortranOrder) {
      for (int i = 0; i < shape.length; i++) {
        index += indices[i] * stride;
        stride *= shape[i];
      }
    } else {
      for (int i = shape.length - 1; i >= 0; i--) {
        index += indices[i] * stride;
        stride *= shape[i];
      }
    }
    return index;
  }

  List result = oneDimensionalList;
  final indices = List.filled(shape.length, 0);

  void reshapeRecursive(int dimension) {
    if (dimension == shape.length - 1) {
      result = List.generate(shape[dimension], (i) {
        indices[dimension] = i;
        return oneDimensionalList[getIndex(indices)];
      });
    } else {
      result = List.generate(shape[dimension], (i) {
        indices[dimension] = i;
        reshapeRecursive(dimension + 1);
        return result;
      });
    }
  }

  reshapeRecursive(0);
  return result;
}

class NpyHeaderSection {
  const NpyHeaderSection({
    required this.version,
    required this.header,
    required this.headerSize,
  });

  final NpyVersion version;
  final int headerSize;
  final NpyHeader header;

  factory NpyHeaderSection.fromList(List list, {NpyDType? dtype, NpyEndian? endian, bool? fortranOrder}) =>
      NpyHeaderSection.fromHeader(NpyHeader.fromList(list, dtype: dtype, endian: endian, fortranOrder: fortranOrder));

  factory NpyHeaderSection.fromHeader(NpyHeader header) {
    final headerSize = header.asBytes.length;
    final firstVersionSizeWithoutPadding = magicString.length +
        NpyVersion.numberOfReservedBytes +
        NpyVersion.numberOfHeaderSizeBytesV1 +
        headerSize +
        newLineOffset;
    final paddingSize = getPaddingSize(firstVersionSizeWithoutPadding);
    final version = NpyVersion.fromString(header.string, headerSize + paddingSize + _newLineInt);

    return NpyHeaderSection(
      version: version,
      headerSize: headerSize,
      header: header,
    );
  }

  /// Returns the size of the entire header section.
  int get size => magicString.length + NpyVersion.numberOfReservedBytes + version.numberOfHeaderBytes + headerSize;

  /// Returns entire header section represented by a List of bytes that includes the magic string, the version, the
  /// number of bytes describing the header length, the header length, and the header, padded with spaces and terminated
  /// with a newline character to be a multiple of 64 bytes. It takes the header as a String and leaves it unchanged.
  List<int> get asBytes => [...magicString.codeUnits, ...version.asBytes, ...headerSizeAsBytes, ...header.asBytes];

  /// Returns a list of bytes that encodes the [headerSize]. The list length depends on the major version.
  List<int> get headerSizeAsBytes {
    if (version.major == 1) {
      assert(headerSize <= NpyVersion.maxFirstVersionSize);
      return (ByteData(NpyVersion.numberOfHeaderSizeBytesV1)..setUint16(0, headerSize, Endian.little))
          .buffer
          .asUint8List();
    }

    assert(headerSize <= NpyVersion.maxHigherVersionSize);
    return (ByteData(NpyVersion.numberOfHeaderSizeBytesHigherVersions)..setUint32(0, headerSize, Endian.little))
        .buffer
        .asUint8List();
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
    } else if (!_supportedMinorVersions.contains(bytes.elementAt(1))) {
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
    required this.paddingSize,
  });

  final NpyDType dtype;
  final bool fortranOrder;
  final List<int> shape;
  final String string;
  final int paddingSize;

  factory NpyHeader.buildPadding({
    required NpyDType dtype,
    required bool fortranOrder,
    required List<int> shape,
    required String string,
  }) {
    final sizeWithoutPadding = magicString.length +
        NpyVersion.numberOfReservedBytes +
        NpyVersion.numberOfHeaderSizeBytesV1 +
        string.length +
        newLineOffset;

    return NpyHeader(
      dtype: dtype,
      fortranOrder: fortranOrder,
      shape: shape,
      string: string,
      paddingSize: getPaddingSize(sizeWithoutPadding),
    );
  }

  factory NpyHeader.buildString({required NpyDType dtype, required bool fortranOrder, required List<int> shape}) {
    final shapeString = shape.isEmpty
        ? '()'
        : shape.length == 1
            ? '(${shape.first},)'
            : '(${shape.join(', ')})';
    final string = "{'descr': '$dtype', 'fortran_order': ${fortranOrder ? 'True' : 'False'}, 'shape': $shapeString, }";
    return NpyHeader.buildPadding(dtype: dtype, fortranOrder: fortranOrder, shape: shape, string: string);
  }

  static String getDictString(
    String headerString,
    String key, [
    String openingDelimiter = "'",
    String closingDelimiter = "'",
  ]) {
    final keyIndex = headerString.indexOf(key);
    if (keyIndex == -1) throw NpyInvalidHeaderException(message: "Missing '$key' field.");

    final firstIndex = headerString.indexOf(openingDelimiter, keyIndex + key.length + 1);
    if (firstIndex == -1) {
      throw NpyInvalidHeaderException(message: "Missing opening delimiter '$openingDelimiter' of '$key' field.");
    }

    final lastIndex = headerString.indexOf(closingDelimiter, firstIndex + 1);
    if (lastIndex == -1) {
      throw NpyInvalidHeaderException(message: "Missing closing delimiter '$closingDelimiter' of '$key' field.");
    }

    return headerString.substring(firstIndex + 1, lastIndex);
  }

  factory NpyHeader.fromBytes(List<int> headerBytes) {
    final lastCharIndex = headerBytes.lastIndexWhere((byte) => byte != _blankSpaceInt && byte != _newLineInt);
    final headerString = String.fromCharCodes(headerBytes.sublist(0, lastCharIndex + 1));

    final descr = getDictString(headerString, 'descr');
    final fortranOrderString = getDictString(headerString, 'fortran_order', ':', ',');
    final shapeString = getDictString(headerString, 'shape', '(', ')');

    late final bool fortranOrder;
    switch (fortranOrderString.trim()) {
      case 'True':
        fortranOrder = true;
      case 'False':
        fortranOrder = false;
      default:
        throw NpyInvalidHeaderException(message: "Invalid 'fortran_order' field: '$fortranOrderString'");
    }

    late final List<int> shape;
    if (shapeString.isEmpty) {
      shape = const [];
    } else {
      shape = shapeString.split(',').where((s) => s.trim().isNotEmpty).map((s) => int.parse(s.trim())).toList();
    }

    return NpyHeader(
      dtype: NpyDType.fromString(descr),
      fortranOrder: fortranOrder,
      shape: shape,
      string: headerString,
      paddingSize: headerBytes.length - lastCharIndex - 1 - newLineOffset,
    );
  }

  factory NpyHeader.fromList(
    List list, {
    NpyDType? dtype,
    NpyEndian? endian,
    bool? fortranOrder,
    List<int> shape = const [],
  }) {
    assert(endian == null || dtype == null, 'Do not specify both dtype and endian. Define endian within dtype.');

    if (list.isEmpty) {
      return NpyHeader.buildString(
        dtype: dtype ??
            NpyDType.fromArgs(
              endian: endian ?? NpyEndian.little,
              type: NpyType.float,
              itemSize: NpyDType.defaultItemSize,
            ),
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
    } else if (firstElement is bool) {
      obtainedType = NpyType.boolean;
    } else if (firstElement is List) {
      return NpyHeader.fromList(
        list.first as List,
        dtype: dtype,
        endian: endian,
        fortranOrder: fortranOrder,
        shape: updatedShape,
      );
    } else {
      throw NpyUnsupportedTypeException(message: 'Unsupported input type: ${firstElement.runtimeType}');
    }

    return NpyHeader.buildString(
      dtype: NpyDType.fromArgs(
        endian: endian ?? dtype?.endian ?? NpyEndian.little,
        itemSize: dtype?.itemSize ?? NpyDType.defaultItemSize,
        type: obtainedType,
      ),
      fortranOrder: fortranOrder ?? false,
      shape: updatedShape,
    );
  }

  /// Returns the header string as a List<int> of bytes.
  List<int> get asBytes => [...utf8.encode(string), ...List.filled(paddingSize, _blankSpaceInt), _newLineInt];
}

/// The ASCII code for a space character.
const _blankSpaceInt = 32;

/// The ASCII code for a newline character.
const _newLineInt = 10;

/// The header section is terminated with a single byte that is a newline character.
const newLineOffset = 1;

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

  const NpyDType.boolean()
      : endian = NpyEndian.none,
        type = NpyType.boolean,
        itemSize = 1;

  const NpyDType.string({required this.itemSize})
      : endian = NpyEndian.none,
        type = NpyType.string;

  final NpyEndian endian;
  final NpyType type;
  final int itemSize;

  static const defaultItemSize = 8;

  factory NpyDType.fromArgs({NpyEndian? endian, required NpyType type, required int itemSize}) {
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
      case NpyType.boolean:
        return const NpyDType.boolean();
      case NpyType.string:
        return NpyDType.string(itemSize: itemSize);
      default:
        throw NpyUnsupportedNpyTypeException(message: 'Unsupported NpyType: $type');
    }
  }

  factory NpyDType.fromString(String string) {
    if (string.length < 3) throw NpyInvalidDTypeException(message: "'descr' field has insufficient length: '$string'");

    try {
      return NpyDType.fromArgs(
        endian: NpyEndian.fromChar(string[0]),
        type: NpyType.fromChar(string[1]),
        itemSize: int.parse(string.substring(2)),
      );
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
      (type) => type.chars.contains(char),
      orElse: () => throw NpyUnsupportedNpyTypeException(message: 'Unsupported list type: $char'),
    );
  }
}
