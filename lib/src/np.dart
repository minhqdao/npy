import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';

/// Loads an NPY file from the given [path].
Future<NpyFile> loadNpy(String path) async {
  final stream = File(path).openRead();
  List<int> buffer = [];
  bool magicNumberChecked = false;
  try {
    await for (final chunk in stream) {
      buffer = [...buffer, ...chunk];
      if (!magicNumberChecked && buffer.length >= _magicNumbers.length) {
        if (!isMagicNumber(buffer.take(_magicNumbers.length))) {
          throw NpInvalidMagicNumberException(path: path);
        }
        magicNumberChecked = true;
      }
    }
  } on FileSystemException catch (e) {
    if (e.osError?.errorCode == 2) throw NpFileNotExistsException(path: path);
    throw NpFileOpenException(path: path, error: e.toString());
  } on NpInvalidMagicNumberException catch (_) {
    rethrow;
  } catch (e) {
    throw NpFileOpenException(path: path, error: e.toString());
  }
  throw NpInsufficientLengthException(path: path);
}

/// Corresponds to the string "\x93NUMPY" and marks the beginning of an NPY file.
const _magicNumbers = [147, 78, 85, 77, 80, 89];

/// Whether the given bytes represent the magic number of an NPY file. NPY files start with the magic number "\x93NUMPY".
bool isMagicNumber(Iterable<int> bytes) => const IterableEquality().equals(bytes, _magicNumbers);
