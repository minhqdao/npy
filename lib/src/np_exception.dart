abstract class NpException implements Exception {
  const NpException();

  String get message;

  @override
  String toString() => message;
}

class NpFileNotExistsException extends NpException {
  const NpFileNotExistsException({required this.path});

  final String path;

  @override
  String get message => "File '$path' does not exist.";
}

class NpFileOpenException extends NpException {
  const NpFileOpenException({required this.path, required this.error});

  final String path;
  final String error;

  @override
  String get message => "Could not open file '$path': $error.";
}

class NpInvalidMagicNumberException extends NpException {
  const NpInvalidMagicNumberException({required this.path});

  final String path;

  @override
  String get message => "Invalid magic number in file '$path'.";
}

class NpInvalidVersionException extends NpException {
  const NpInvalidVersionException({required this.message});

  @override
  final String message;
}

class NpInsufficientLengthException extends NpException {
  const NpInsufficientLengthException({required this.path});

  final String path;

  @override
  String get message => "NPY file '$path' has insufficient length.";
}
