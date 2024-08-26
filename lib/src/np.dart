import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
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
  final stream = File(path).openRead();

  List<int> buffer = [];
  bool isMagicStringChecked = false;
  NpyVersion? version;
  int? headerLength;
  NpyHeader? header;

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
        headerLength = NpyHeader.getLength(
          bytes: buffer.skip(magicString.length + NpyVersion.reservedBytes).take(version.numberOfHeaderBytes).toList(),
          version: version,
        );
      }

      if (header == null &&
          headerLength != null &&
          version != null &&
          buffer.length >= magicString.length + NpyVersion.reservedBytes + version.numberOfHeaderBytes + headerLength) {
        header = NpyHeader.fromString(
          String.fromCharCodes(
            buffer
                .skip(magicString.length + NpyVersion.reservedBytes + version.numberOfHeaderBytes)
                .take(headerLength)
                .toList(),
          ),
        );
      }

      if (header != null && headerLength != null && version != null) {
        return NDArray(
          version: version,
          headerLength: headerLength,
          header: header,
          data: [],
        );
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

/// Whether the given bytes represent the magic string that NPY files start with.
bool isMagicString(Iterable<int> bytes) => const IterableEquality().equals(bytes, magicString.codeUnits);

/// Marks the beginning of an NPY file.
const magicString = '\x93NUMPY';

/// Determines the size of the given [header] as a List<int> for the given NPY file [version].
List<int> headerSize(String header, int version) {
  final headerLength = utf8.encode(header).length;
  List<int> headerSizeBytes;
  if (version == 1) {
    assert(headerLength < 65536);
    headerSizeBytes = [headerLength & 0xFF, (headerLength >> 8) & 0xFF];
  } else if (version >= 2) {
    headerSizeBytes = [
      headerLength & 0xFF,
      (headerLength >> 8) & 0xFF,
      (headerLength >> 16) & 0xFF,
      (headerLength >> 24) & 0xFF,
    ];
  } else {
    throw ArgumentError('Unsupported NPY version');
  }
  return headerSizeBytes;
}
