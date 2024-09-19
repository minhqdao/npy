import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';

/// Loads an NPY file from the given [path] and returns an [NdArray] object.
///
/// If you're expecting a specific type of list, you can use the generic type parameter [T] to specify it as such:
///
/// ```dart
/// void main() async {
///  final NdArray<double> ndarray = await load<double>('example.npy');
///  final List<double> list = ndarray.list;
///  print(list);
///}
/// ```
Future<NdArray<T>> load<T>(String path) async {
  if (T != dynamic && T != int && T != double) {
    throw NpyUnsupportedTypeException(message: 'Unsupported NdArray type: $T');
  }

  final stream = File(path).openRead();

  final List<int> buffer = [];
  final parser = NpyParser();
  int dataOffset = 0;
  int elementsRead = 0;
  final List<T> list = [];

  try {
    await for (final chunk in stream) {
      buffer.addAll(chunk);

      parser
        ..checkMagicString(buffer)
        ..getVersion(buffer)
        ..getHeaderSize(buffer)
        ..getHeader(buffer)
        ..buildHeaderSection();

      if (parser.isNotReadyForData) continue;

      if (parser.header!.shape.isEmpty) return NdArray<T>(headerSection: parser.headerSection!, data: const []);

      dataOffset = parser.headerSection!.size + elementsRead * parser.header!.dtype.itemSize;
      final totalElements = parser.header!.shape.reduce((a, b) => a * b);
      final remainingElements = totalElements - elementsRead;
      final elementsInBuffer = (buffer.length - dataOffset) ~/ parser.header!.dtype.itemSize;
      final elementsToProcess = min(remainingElements, elementsInBuffer);

      final newData = parseBytes<T>(
        buffer.sublist(dataOffset, dataOffset + elementsToProcess * parser.header!.dtype.itemSize),
        parser.header!,
      );

      list.addAll(newData);
      elementsRead += elementsToProcess;

      if (elementsRead == totalElements) return NdArray<T>(headerSection: parser.headerSection!, data: list);

      dataOffset += elementsToProcess * parser.header!.dtype.itemSize;
    }
  } on FileSystemException catch (e) {
    if (e.osError?.errorCode == 2) throw NpFileNotExistsException(path: path);
    throw NpFileOpenException(path: path, error: e.toString());
  } on NpyParseException {
    rethrow;
  } catch (e) {
    throw NpFileOpenException(path: path, error: e.toString());
  }
  throw NpyParseException(message: "Error parsing '$path' as an NPY file.");
}

List<T> parseBytes<T>(List<int> bytes, NpyHeader header) {
  final dtype = header.dtype;
  final numberOfElements = bytes.length ~/ dtype.itemSize;

  late final List<T> result;
  switch (dtype.type) {
    case NpyType.float:
      result = List.filled(numberOfElements, .0 as T);
    case NpyType.int:
    case NpyType.uint:
      result = List.filled(numberOfElements, 0 as T);
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
      throw NpyUnsupportedDTypeException(message: 'Unsupported endian: ${dtype.endian}');
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
      default:
        throw NpyUnsupportedDTypeException(message: 'Unsupported dtype: $dtype');
    }
  }

  return reshape(result, header.shape).cast<T>();
}

List<dynamic> reshape<T>(List<T> oneDimensionalList, List<int> shape) {
  if (oneDimensionalList.isEmpty) return const [];
  if (shape.isEmpty) throw const NpyParseException(message: 'Shape must not be empty.');

  if (oneDimensionalList.length != shape.reduce((a, b) => a * b)) {
    throw const NpyParseException(
      message: 'The total number of elements does not equal the product of the shape dimensions.',
    );
  }

  return _reshapeRecursive(oneDimensionalList, shape);
}

List _reshapeRecursive<T>(List<T> oneDimensionalList, List<int> shape) {
  if (shape.length == 1) return oneDimensionalList.sublist(0, shape[0]);

  final step = shape.skip(1).reduce((a, b) => a * b);
  final reshapedList = [];

  for (int i = 0; i < shape[0]; i++) {
    reshapedList.add(_reshapeRecursive<T>(oneDimensionalList.sublist(i * step, (i + 1) * step), shape.sublist(1)));
  }

  return reshapedList;
}

/// Saves the [List] to the given [path] in NPY format.
///
/// The [List] has to be of a supported type, which are currently [int] and [double].
Future<void> saveList(String path, List list, {NpyDType? dtype, bool? fortranOrder}) async =>
    save(path, NdArray.fromList(list, dtype: dtype, fortranOrder: fortranOrder));

/// Saves the [NdArray] to the given [path] in NPY format.
///
/// The [NdArray] can be conveniently created using the [NdArray.fromList] constructor.
///
/// Example:
/// ```dart
/// void main() async {
/// final ndarray = NdArray.fromList([1.0, 2.0, 3.0]);
/// await save('example.npy', ndarray);
/// }
/// ```
Future<void> save(String path, NdArray ndarray) async => File(path).writeAsBytes(ndarray.asBytes);
