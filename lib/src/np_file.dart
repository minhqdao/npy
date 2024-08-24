import 'package:npy/src/np_exception.dart';

abstract class NpyFile {
  const NpyFile({
    required this.ndarray,
    required this.dtype,
    required this.shape,
  });

  final List<dynamic> ndarray;
  final DType dtype;
  final List<int> shape;
}

class NpyFileInt implements NpyFile {
  const NpyFileInt({
    required this.ndarray,
    required this.dtype,
    required this.shape,
  });

  @override
  final List<int> ndarray;
  final DType dtype;
  final List<int> shape;
}

class NpzFile {
  const NpzFile({
    required this.files,
  });

  final Map<String, NpyFile> files;
}

class NpVersion {
  const NpVersion({
    required this.major,
    required this.minor,
  });

  final int major;
  final int minor;

  static const _supportedMajorVersions = {1, 2, 3};
  static const _supportedMinorVersions = {0};

  factory NpVersion.fromBytes(Iterable<int> bytes) {
    if (bytes.length != 2) throw const NpInvalidVersionException(message: 'Version must have exactly two bytes.');
    if (!_supportedMajorVersions.contains(bytes.elementAt(0))) {
      throw NpInvalidVersionException(message: 'Unsupported major version: ${bytes.elementAt(0)}.');
    }
    if (!_supportedMinorVersions.contains(bytes.elementAt(1))) {
      throw NpInvalidVersionException(message: 'Unsupported minor version: ${bytes.elementAt(1)}.');
    }
    return NpVersion(major: bytes.elementAt(0), minor: bytes.elementAt(1));
  }
}

enum DType {
  bool,
  int8,
  int16,
  int32,
  int64,
  uint8,
  uint16,
  uint32,
  uint64,
  float16,
  float32,
  float64,
  complex64,
  complex128,
}
