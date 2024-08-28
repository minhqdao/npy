import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';

/// Loads an NPY file from the given [path] and returns an [NdArray] object.
///
/// If you're expecting a specific type of data, you can use the generic type parameter [T] to specify it as such:
///
/// ```dart
/// void main() async {
///  final NdArray<double> ndarray = await load<double>('example.npy');
///  final List<double> data = ndarray.data;
///  print(data);
///}
/// ```
Future<NdArray<T>> load<T>(String path) async {
  if (T != dynamic && T != int && T != double) {
    throw NpyUnsupportedTypeException(message: 'Unsupported NdArray type: $T');
  }

  final stream = File(path).openRead();

  List<int> buffer = [];
  final headerSection = NpyHeaderSection();
  int dataOffset = 0;
  int dataRead = 0;
  final List<T> data = [];

  try {
    await for (final chunk in stream) {
      buffer.addAll(chunk);

      headerSection
        ..checkMagicString(buffer)
        ..parseVersion(buffer)
        ..parseHeaderLength(buffer)
        ..parseHeader(buffer);

      if (headerSection.header != null && headerSection.headerLength != null && headerSection.version != null) {
        if (headerSection.header!.shape.isEmpty) return NdArray<T>(headerSection: headerSection);

        dataOffset = magicString.length +
            NpyHeaderSection.numberOfVersionBytes +
            headerSection.numberOfHeaderBytes +
            headerSection.headerLength!;

        final totalElements = headerSection.header!.shape.reduce((a, b) => a * b);

        while (dataOffset < buffer.length) {
          final remainingElements = totalElements - dataRead;
          final elementsInBuffer = (buffer.length - dataOffset) ~/ headerSection.header!.dtype.itemSize;
          final elementsToProcess = min(remainingElements, elementsInBuffer);

          final newData = _parseData<T>(
            buffer.sublist(dataOffset, dataOffset + elementsToProcess * headerSection.header!.dtype.itemSize),
            headerSection.header!.dtype,
            elementsToProcess,
          );

          data.addAll(newData);
          dataRead += elementsToProcess;
          dataOffset += elementsToProcess * headerSection.header!.dtype.itemSize;

          if (dataRead == totalElements) {
            return NdArray<T>(
              headerSection: headerSection,
              data: data,
            );
          }
        }

        buffer = buffer.sublist(dataOffset);
        dataOffset = 0;
      }
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

List<T> _parseData<T>(List<int> bytes, NpyDType dtype, int count) {
  final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
  final result = List<T>.filled(count, null as T);

  for (int i = 0; i < count; i++) {
    switch (dtype.toString()) {
      case '<f4':
        result[i] = byteData.getFloat32(i * 4, Endian.little) as T;
      case '>f4':
        result[i] = byteData.getFloat32(i * 4) as T;
      case '<f8':
        result[i] = byteData.getFloat64(i * 8, Endian.little) as T;
      case '>f8':
        result[i] = byteData.getFloat64(i * 8) as T;
      case '<i4':
        result[i] = byteData.getInt32(i * 4, Endian.little) as T;
      case '>i4':
        result[i] = byteData.getInt32(i * 4) as T;
      case '<i8':
        result[i] = byteData.getInt64(i * 8, Endian.little) as T;
      case '>i8':
        result[i] = byteData.getInt64(i * 8) as T;
      case '<u4':
        result[i] = byteData.getUint32(i * 4, Endian.little) as T;
      case '>u4':
        result[i] = byteData.getUint32(i * 4) as T;
      case '<u8':
        result[i] = byteData.getUint64(i * 8, Endian.little) as T;
      case '>u8':
        result[i] = byteData.getUint64(i * 8) as T;
      default:
        throw NpyUnsupportedDTypeException(message: 'Unsupported dtype: $dtype');
    }
  }

  return result;
}

/// Saves the given [NdArray] to the given [path] in NPY format.
Future<void> save(String path, NdArray ndarray) async => File(path).writeAsBytes(ndarray.asBytes);

/// Saves the given [List] to the given [path] in NPY format.
Future<void> saveList<T>(String path, List<T> data) async => save(path, NdArray<T>.fromList(data));
