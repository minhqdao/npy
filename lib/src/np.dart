import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';

/// Loads an NPY file from the given [path].
Future<NpyFile> loadNpy(String path) async {
  final stream = File(path).openRead();
  List<int> buffer = [];
  bool isMagicStringChecked = false;
  NpyVersion? version;
  int? numberOfHeaderBytes;
  int? headerLength;
  try {
    await for (final chunk in stream) {
      buffer = [...buffer, ...chunk];
      if (!isMagicStringChecked && buffer.length >= magicString.length) {
        if (!isMagicString(buffer.take(magicString.length))) {
          throw NpyInvalidMagicNumberException(message: "Invalid magic number in '$path'.");
        }
        isMagicStringChecked = true;
      }
      if (version == null && buffer.length >= magicString.length + 2) {
        version = NpyVersion.fromBytes(buffer.skip(magicString.length).take(2));
        numberOfHeaderBytes = version.major == 1 ? 2 : 4;
      }
      if (headerLength == null &&
          version != null &&
          numberOfHeaderBytes != null &&
          buffer.length >= magicString.length + 2 + numberOfHeaderBytes) {
        final bytesTaken = buffer.skip(magicString.length + 2).take(numberOfHeaderBytes).toList();
        headerLength = version.major == 1 ? littleEndian16ToInt(bytesTaken) : littleEndian32ToInt(bytesTaken);
      }
      if (version != null &&
          headerLength != null &&
          numberOfHeaderBytes != null &&
          buffer.length >= magicString.length + 2 + numberOfHeaderBytes + headerLength) {
        final headerBytes = buffer.skip(magicString.length + 2 + numberOfHeaderBytes).take(headerLength).toList();
        final header = NpyHeader.fromString(String.fromCharCodes(headerBytes));
        return NpyFileInt(version: version, headerLength: headerLength, header: header);
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
  throw NpyParseException(message: "Error parsing file '$path' as an NPY file.");
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
    if (headerLength > 65535) throw ArgumentError('Header too large for version 1.0 NPY file');
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
