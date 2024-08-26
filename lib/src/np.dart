import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';

/// Loads an NPY file from the given [path].
///
/// If you're expecting a specific type of data, you can use the generic type parameter [T] to specify it as such:
///
/// ```dart
/// void main() async {
///  final npyFile = await loadNpy<double>('example.npy');
///  final List<double> array = npyFile.data;
///  print(array);
///}
/// ```
Future<NpyFile<T>> loadNpy<T>(String path) async {
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
        final bytesTaken =
            buffer.skip(magicString.length + NpyVersion.reservedBytes).take(version.numberOfHeaderBytes).toList();
        headerLength = version.major == 1 ? littleEndian16ToInt(bytesTaken) : littleEndian32ToInt(bytesTaken);
      }

      if (header == null &&
          headerLength != null &&
          version != null &&
          buffer.length >= magicString.length + NpyVersion.reservedBytes + version.numberOfHeaderBytes + headerLength) {
        final headerBytes = buffer
            .skip(magicString.length + NpyVersion.reservedBytes + version.numberOfHeaderBytes)
            .take(headerLength)
            .toList();
        header = NpyHeader.fromString(String.fromCharCodes(headerBytes));
      }

      if (header != null && headerLength != null && version != null) {
        return NpyFileInt(
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
