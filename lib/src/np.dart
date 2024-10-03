import 'dart:async';
import 'dart:io';

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
Future<NdArray<T>> load<T>(String path, {int? bufferSize}) async {
  if (T != dynamic && T != double && T != int && T != bool) {
    throw NpyInvalidNpyTypeException(message: 'Unsupported NdArray type: $T');
  }

  final stream = File(path).openRead().transform(ChunkTransformer(bufferSize: bufferSize));

  final List<int> buffer = [];
  final parser = NpyParser();

  try {
    await for (final chunk in stream) {
      buffer.addAll(chunk);

      parser
        ..checkMagicString(buffer)
        ..getVersion(buffer)
        ..getHeaderSize(buffer)
        ..getHeader(buffer)
        ..buildHeaderSection()
        ..getData(buffer);

      if (parser.isCompleted) return NdArray(headerSection: parser.headerSection!, data: parser.data);
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

/// Saves the [List] to the given [path] in NPY format.
///
/// The [List] has to be of a supported type, which are currently [double], [int] and [bool].
Future<void> saveList(String path, List list, {NpyDType? dtype, NpyEndian? endian, bool? fortranOrder}) async =>
    save(path, NdArray.fromList(list, dtype: dtype, endian: endian, fortranOrder: fortranOrder));

/// Saves an [NdArray] to the given [path] in NPY format.
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
