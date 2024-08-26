import 'dart:io';

import 'package:npy/npy.dart';
import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';
import 'package:test/test.dart';

void main() {
  group('Check magic number:', () {
    test('Valid code units', () => expect(isMagicString([147, 78, 85, 77, 80, 89]), true));
    test('Invalid first byte', () => expect(isMagicString([146, 78, 85, 77, 80, 89]), false));
    test('Invalid last byte', () => expect(isMagicString([147, 78, 85, 77, 80, 87]), false));
    test('Too short', () => expect(isMagicString([147, 78, 85, 77, 80]), false));
    test('Too long', () => expect(isMagicString([147, 78, 85, 77, 80, 89, 90]), false));
    test('From valid text', () => expect(isMagicString('\x93NUMPY'.codeUnits), true));
  });

  group('Parse NpyVersion:', () {
    test('Supported version', () {
      final version = NpyVersion.fromBytes([1, 0]);
      expect(version.major, 1);
      expect(version.minor, 0);
    });
    test('Unsupported major version', () {
      expect(() => NpyVersion.fromBytes([4, 0]), throwsA(const TypeMatcher<NpyUnsupportedVersionException>()));
    });
    test('Unsupported minor version', () {
      expect(() => NpyVersion.fromBytes([1, 1]), throwsA(const TypeMatcher<NpyUnsupportedVersionException>()));
    });
  });

  group('Parse NpyByteOrder:', () {
    test('Little Endian byte order', () => expect(NpyByteOrder.fromChar('<'), NpyByteOrder.littleEndian));
    test('Big Endian byte order', () => expect(NpyByteOrder.fromChar('>'), NpyByteOrder.bigEndian));
    test('Native byte order', () => expect(NpyByteOrder.fromChar('='), NpyByteOrder.nativeEndian));
    test('No byte order', () => expect(NpyByteOrder.fromChar('|'), NpyByteOrder.none));
    test('Invalid byte order', () {
      expect(() => NpyByteOrder.fromChar('!'), throwsA(const TypeMatcher<NpyUnsupportedByteOrderException>()));
    });
  });

  group('Parse NpyType:', () {
    test('Boolean type', () => expect(NpyType.fromChar('b'), NpyType.boolean));
    test('Integer type', () => expect(NpyType.fromChar('i'), NpyType.int));
    test('Unsigned integer type', () => expect(NpyType.fromChar('u'), NpyType.uint));
    test('Float type', () => expect(NpyType.fromChar('f'), NpyType.float));
    test('Complex type', () => expect(NpyType.fromChar('c'), NpyType.complex));
    test('String type', () => expect(NpyType.fromChar('S'), NpyType.string));
    test('Unicode type', () => expect(NpyType.fromChar('U'), NpyType.unicode));
    test('Void type', () => expect(NpyType.fromChar('V'), NpyType.voidType));
    test('Invalid type', () {
      expect(() => NpyType.fromChar('a'), throwsA(const TypeMatcher<NpyUnsupportedTypeException>()));
    });
  });

  group('Parse NpyDType:', () {
    test('Empty string', () {
      expect(() => NpyDType.fromString(''), throwsA(const TypeMatcher<NpyInvalidDTypeException>()));
    });
    test('String too short', () {
      expect(() => NpyDType.fromString('<f'), throwsA(const TypeMatcher<NpyInvalidDTypeException>()));
    });
    test('Invalid descr', () {
      expect(() => NpyDType.fromString('f>8'), throwsA(const TypeMatcher<NpyInvalidDTypeException>()));
    });
    test('<f8', () {
      final dtype = NpyDType.fromString('<f8');
      expect(dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(dtype.kind, NpyType.float);
      expect(dtype.itemsize, 8);
    });
    test('>f4', () {
      final dtype = NpyDType.fromString('>f4');
      expect(dtype.byteOrder, NpyByteOrder.bigEndian);
      expect(dtype.kind, NpyType.float);
      expect(dtype.itemsize, 4);
    });
    test('|S10', () {
      final dtype = NpyDType.fromString('|S10');
      expect(dtype.byteOrder, NpyByteOrder.none);
      expect(dtype.kind, NpyType.string);
      expect(dtype.itemsize, 10);
    });
  });

  group('Parse NpyHeader:', () {
    test('Empty header', () {
      expect(() => NpyHeader.fromString(''), throwsA(const TypeMatcher<NpyInvalidHeaderException>()));
    });
    test('Only curly braces', () {
      expect(() => NpyHeader.fromString('{}'), throwsA(const TypeMatcher<NpyInvalidHeaderException>()));
    });
    test('Something random', () {
      expect(() => NpyHeader.fromString('xyz'), throwsA(const TypeMatcher<NpyInvalidHeaderException>()));
    });
    test('<f8, False, (3,)', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': False, 'shape': (3,)}");
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
      expect(header.dtype.itemsize, 8);
      expect(header.fortranOrder, false);
      expect(header.shape, [3]);
    });
    test('<f8, True, (3,)', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (3,)}");
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
      expect(header.dtype.itemsize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [3]);
    });
    test('<f8, null, (3,)', () {
      expect(
        () => NpyHeader.fromString("{'descr': '<f8', 'fortran_order': null, 'shape': (3,)}"),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
    test('>i4, True, (3,)', () {
      final header = NpyHeader.fromString("{'descr': '>i4', 'fortran_order': True, 'shape': (3,)}");
      expect(header.dtype.byteOrder, NpyByteOrder.bigEndian);
      expect(header.dtype.kind, NpyType.int);
      expect(header.dtype.itemsize, 4);
      expect(header.fortranOrder, true);
      expect(header.shape, [3]);
    });
    test('|S200, True, (3,)', () {
      final header = NpyHeader.fromString("{'descr': '|S200', 'fortran_order': True, 'shape': (3,)}");
      expect(header.dtype.byteOrder, NpyByteOrder.none);
      expect(header.dtype.kind, NpyType.string);
      expect(header.dtype.itemsize, 200);
      expect(header.fortranOrder, true);
      expect(header.shape, [3]);
    });
    test('<x4, True, (3,)', () {
      expect(
        () => NpyHeader.fromString("{'descr': '<x4', 'fortran_order': True, 'shape': (3,)}"),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
    test('Missing descr', () {
      expect(
        () => NpyHeader.fromString("{'fortran_order': True, 'shape': (3,)}"),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
    test('Missing fortran_order', () {
      expect(
        () => NpyHeader.fromString("{'descr': '<f8', 'shape': (3,)}"),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
    test('Missing shape', () {
      expect(
        () => NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True}"),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
    test('<f8, True, ()', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': ()}");
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
      expect(header.dtype.itemsize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, []);
    });
    test('<f8, True, (2, 3)', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (2, 3)}");
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
      expect(header.dtype.itemsize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3]);
    });
    test('<f8, True, (2, 3, 4)', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (2, 3, 4)}");
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
      expect(header.dtype.itemsize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3, 4]);
    });
    test('Invalid shape', () {
      expect(
        () => NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': [2, 3]}"),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
  });

  group('Load npy:', () {
    test('Non-existent file', () {
      expect(loadNpy('not_existent.npy'), throwsA(const TypeMatcher<NpFileNotExistsException>()));
    });
    test('Pointing at current directory', () {
      expect(loadNpy('.'), throwsA(const TypeMatcher<NpFileOpenException>()));
    });
    test('Empty file', () {
      const filename = 'empty_file.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    test('Insufficient length', () {
      const filename = 'insufficient_length.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([1, 2, 3]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    test('Invalid magic number', () {
      const filename = 'invalid_magic_number.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([1, 2, 3, 4, 5, 6]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpyInvalidMagicNumberException>()));
      tmpFile.deleteSync();
    });
    test('Unsupported major version', () {
      const filename = 'unsupported_major_version.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 4, 0]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    test('Unsupported minor version', () {
      const filename = 'unsupported_minor_version.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 1, 1]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    // test('Supported version 1', () async {
    //   const filename = 'supported_version_1.tmp';
    //   final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 1, 0, 0x78, 0x56, 0x34, 0x12]);
    //   final npyFile = await loadNpy(filename);
    //   expect(npyFile.version.major, 1);
    //   expect(npyFile.version.minor, 0);
    //   expect(npyFile.headerLength, 0x5678);
    //   expect(npyFile.headerLength, 22136);
    //   tmpFile.deleteSync();
    // });
    // test('Supported version 2', () async {
    //   const filename = 'supported_version_2.tmp';
    //   final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 2, 0, 0x78, 0x56, 0x34, 0x12]);
    //   final npyFile = await loadNpy(filename);
    //   expect(npyFile.version.major, 2);
    //   expect(npyFile.version.minor, 0);
    //   expect(npyFile.headerLength, 0x12345678);
    //   expect(npyFile.headerLength, 305419896);
    //   tmpFile.deleteSync();
    // });
    // test('Supported version 3', () async {
    //   const filename = 'supported_version_3.tmp';
    //   final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 3, 0, 0x78, 0x56, 0x34, 0x12]);
    //   final npyFile = await loadNpy(filename);
    //   expect(npyFile.version.major, 3);
    //   expect(npyFile.version.minor, 0);
    //   expect(npyFile.headerLength, 0x12345678);
    //   expect(npyFile.headerLength, 305419896);
    //   tmpFile.deleteSync();
    // });

    // test('np.array(0)', () async {
    //   await loadNpy('test/files/array_0.npy');
    //   // expect(loadNpy('test/array_0.npy'), throwsA(const TypeMatcher<int>()));
    // });
  });
}
