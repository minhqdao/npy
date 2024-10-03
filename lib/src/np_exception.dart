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

class NpyInvalidVersionException extends NpyParseException {
  const NpyInvalidVersionException({required super.message});
}

class NpyInvalidHeaderException extends NpyParseException {
  const NpyInvalidHeaderException({required super.message});
}

class NpyInvalidDTypeException extends NpyInvalidHeaderException {
  const NpyInvalidDTypeException({required super.message});
}

class NpyInvalidEndianException extends NpyInvalidDTypeException {
  const NpyInvalidEndianException({required super.message});
}

class NpyInvalidNpyTypeException extends NpyInvalidDTypeException {
  const NpyInvalidNpyTypeException({required super.message});
}

class NpyParseOrderException extends NpyParseException {
  const NpyParseOrderException({required super.message});
}

class NpyWriteException extends NpException {
  const NpyWriteException({required this.message});

  @override
  final String message;
}
