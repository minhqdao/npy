import 'dart:async';
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
  NpVersion? version;
  int? headerLength;
  try {
    await for (final chunk in stream) {
      buffer = [...buffer, ...chunk];
      if (!isMagicStringChecked && buffer.length >= magicString.length) {
        if (!isMagicString(buffer.take(magicString.length))) throw NpInvalidMagicNumberException(path: path);
        isMagicStringChecked = true;
      }
      if (version == null && buffer.length >= magicString.length + 2) {
        version = NpVersion.fromBytes(buffer.skip(magicString.length).take(2));
      }
      if (headerLength == null && version != null) {
        if (version.major == 1 && buffer.length >= magicString.length + 2 + 2) {
          headerLength = _fromLittleEndian16(buffer.skip(magicString.length + 2).take(2).toList());
        } else if (version.major >= 2 && buffer.length >= magicString.length + 2 + 4) {
          headerLength = _fromLittleEndian32(buffer.skip(magicString.length + 2).take(4).toList());
        }
      }
      if (version != null && headerLength != null) return NpyFileInt(version: version, headerLength: headerLength);
    }
  } on FileSystemException catch (e) {
    if (e.osError?.errorCode == 2) throw NpFileNotExistsException(path: path);
    throw NpFileOpenException(path: path, error: e.toString());
  } on NpInvalidMagicNumberException catch (_) {
    rethrow;
  } on NpUnsupportedVersionException catch (_) {
    rethrow;
  } catch (e) {
    throw NpFileOpenException(path: path, error: e.toString());
  }
  throw NpParseException(path: path);
}

/// Whether the given bytes represent the magic string that NPY files start with.
bool isMagicString(Iterable<int> bytes) => const IterableEquality().equals(bytes, magicString.codeUnits);

/// Marks the beginning of an NPY file.
const magicString = '\x93NUMPY';

/// Converts the given [bytes] to a 16-bit unsigned integer in little-endian byte order.
int _fromLittleEndian16(List<int> bytes) {
  assert(bytes.length == 2);
  final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
  return byteData.getUint16(0, Endian.little);
}

/// Converts the given [bytes] to a 32-bit unsigned integer in little-endian byte order.
int _fromLittleEndian32(List<int> bytes) {
  assert(bytes.length == 4);
  final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
  return byteData.getUint32(0, Endian.little);
}
