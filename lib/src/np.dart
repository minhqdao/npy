import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';

/// Loads an NPY file from the given [path].
Future<NpyFile> loadNpy(String path) async {
  final stream = File(path).openRead();
  List<int> buffer = [];
  bool isMagicStringChecked = false;
  NpVersion? version;
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
      if (version != null) return NpyFileInt(version: version);
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
  throw NpInsufficientLengthException(path: path);
}

/// Whether the given bytes represent the magic string that NPY files start with.
bool isMagicString(Iterable<int> bytes) => const IterableEquality().equals(bytes, magicString.codeUnits);

/// Marks the beginning of an NPY file.
const magicString = '\x93NUMPY';
