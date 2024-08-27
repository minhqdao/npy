import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';

/// Loads an NPY file from the given [path] and returns an [NDArray] object.
///
/// If you're expecting a specific type of data, you can use the generic type parameter [T] to specify it as such:
///
/// ```dart
/// void main() async {
///  final NDArray<double> ndarray = await load<double>('example.npy');
///  final List<double> data = ndarray.data;
///  print(data);
///}
/// ```
Future<NDArray<T>> load<T>(String path) async {
  if (T != dynamic && T != int && T != double) {
    throw NpyUnsupportedTypeException(message: 'Unsupported NDArray type: $T');
  }

  final stream = File(path).openRead();

  List<int> buffer = [];
  bool isMagicStringChecked = false;
  NpyVersion? version;
  int? headerLength;
  NpyHeader? header;
  int dataOffset = 0;
  int dataRead = 0;
  List<T> data = [];

  try {
    await for (final chunk in stream) {
      buffer = [...buffer, ...chunk];

      if (!isMagicStringChecked && buffer.length >= magicString.length) {
        if (!isMagicString(buffer.take(magicString.length))) {
          throw NpyInvalidMagicNumberException(message: "Invalid magic number in '$path'.");
        }
        isMagicStringChecked = true;
      }

      if (version == null && buffer.length >= magicString.length + NpyVersion.reservedBytes) {
        version = NpyVersion.fromBytes(buffer.skip(magicString.length).take(NpyVersion.reservedBytes));
      }

      if (headerLength == null &&
          version != null &&
          buffer.length >= magicString.length + NpyVersion.reservedBytes + version.numberOfHeaderBytes) {
        headerLength = version.getHeaderLengthFromBytes(
          buffer.skip(magicString.length + NpyVersion.reservedBytes).take(version.numberOfHeaderBytes).toList(),
        );
      }

      if (header == null &&
          headerLength != null &&
          version != null &&
          buffer.length >= magicString.length + NpyVersion.reservedBytes + version.numberOfHeaderBytes + headerLength) {
        final bytes = buffer
            .skip(magicString.length + NpyVersion.reservedBytes + version.numberOfHeaderBytes)
            .take(headerLength)
            .toList();
        header = NpyHeader.fromString(String.fromCharCodes(bytes));
        dataOffset = magicString.length + NpyVersion.reservedBytes + version.numberOfHeaderBytes + headerLength;
      }

      if (header != null && headerLength != null && version != null) {
        final totalElements = header.shape.reduce((a, b) => a * b);

        while (dataOffset < buffer.length) {
          final remainingElements = totalElements - dataRead;
          final elementsInBuffer = (buffer.length - dataOffset) ~/ header.dtype.itemSize;
          final elementsToProcess = min(remainingElements, elementsInBuffer);

          final newData = _parseData<T>(
            buffer.sublist(dataOffset, dataOffset + elementsToProcess * header.dtype.itemSize),
            header.dtype,
            elementsToProcess,
          );

          data = [...data, ...newData];
          dataRead += elementsToProcess;
          dataOffset += elementsToProcess * header.dtype.itemSize;

          if (dataRead == totalElements) {
            return NDArray<T>(version: version, headerLength: headerLength, header: header, data: data);
          }

          buffer = buffer.sublist(dataOffset);
          dataOffset = 0;
        }
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
