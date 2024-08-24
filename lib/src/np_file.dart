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

  factory NpVersion.fromBytes(Iterable<int> bytes) {
    if (bytes.length != 2) throw const NpInvalidVersionException();
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
