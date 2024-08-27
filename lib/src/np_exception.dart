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

class NpyParseException extends NpException {
  const NpyParseException({required this.message});

  @override
  final String message;
}

class NpyInvalidMagicStringException extends NpyParseException {
  const NpyInvalidMagicStringException({required super.message});
}

class NpyUnsupportedVersionException extends NpyParseException {
  const NpyUnsupportedVersionException({required super.message});
}

class NpyInvalidHeaderException extends NpyParseException {
  const NpyInvalidHeaderException({required super.message});
}

class NpyInvalidDTypeException extends NpyInvalidHeaderException {
  const NpyInvalidDTypeException({required super.message});
}

class NpyUnsupportedByteOrderException extends NpyInvalidDTypeException {
  const NpyUnsupportedByteOrderException({required super.message});
}

class NpyUnsupportedNpyTypeException extends NpyInvalidDTypeException {
  const NpyUnsupportedNpyTypeException({required super.message});
}

class NpyUnsupportedDTypeException extends NpyParseException {
  const NpyUnsupportedDTypeException({required super.message});
}

class NpyUnsupportedTypeException extends NpyParseException {
  const NpyUnsupportedTypeException({required super.message});
}
