import 'dart:io';

import 'package:npy/npy.dart';
import 'package:npy/src/np_exception.dart';
import 'package:test/test.dart';

void main() {
  const double epsilon = 1e-6;
  bool almostEqual(double a, double b, [double tolerance = epsilon]) => (a - b).abs() < tolerance;
  bool listAlmostEquals(List a, List<double> b, [double tolerance = epsilon]) {
    if (a.length != b.length) return false;
    final mappedList = List<double>.from(a.map((e) => e is double ? e : throw 'Not a double'));
    for (int i = 0; i < a.length; i++) {
      if (!almostEqual(mappedList[i], b[i], tolerance)) return false;
    }
    return true;
  }

  group('Check magic string:', () {
    test('Valid code units', () {
      final parser = NpyParser();
      expect(parser.hasPassedMagicStringCheck, false);
      expect(() => parser.checkMagicString([147, 78, 85, 77, 80, 89]), returnsNormally);
      expect(parser.hasPassedMagicStringCheck, true);
    });
    test('Additional bytes', () {
      final parser = NpyParser();
      expect(parser.hasPassedMagicStringCheck, false);
      expect(() => parser.checkMagicString([147, 78, 85, 77, 80, 89, 1, 2, 3]), returnsNormally);
      expect(parser.hasPassedMagicStringCheck, true);
    });
    test('Insufficient bytes', () {
      final parser = NpyParser();
      expect(parser.hasPassedMagicStringCheck, false);
      expect(() => parser.checkMagicString([147, 78, 85, 77, 80]), returnsNormally);
      expect(parser.hasPassedMagicStringCheck, false);
    });
    test('Second run returns early with wrong magic string', () {
      final parser = NpyParser();
      expect(parser.hasPassedMagicStringCheck, false);
      expect(() => parser.checkMagicString([147, 78, 85, 77, 80, 89]), returnsNormally);
      expect(parser.hasPassedMagicStringCheck, true);
      expect(() => parser.checkMagicString([147, 78, 85, 77, 80, 90]), returnsNormally);
      expect(parser.hasPassedMagicStringCheck, true);
    });
    test(
      'Invalid first byte',
      () {
        final parser = NpyParser();
        expect(parser.hasPassedMagicStringCheck, false);
        expect(
          () => parser.checkMagicString([146, 78, 85, 77, 80, 89]),
          throwsA(const TypeMatcher<NpyInvalidMagicStringException>()),
        );
        expect(parser.hasPassedMagicStringCheck, false);
      },
    );
    test(
      'Invalid last byte',
      () {
        final parser = NpyParser();
        expect(parser.hasPassedMagicStringCheck, false);
        expect(
          () => parser.checkMagicString([147, 78, 85, 77, 80, 87]),
          throwsA(const TypeMatcher<NpyInvalidMagicStringException>()),
        );
        expect(parser.hasPassedMagicStringCheck, false);
      },
    );
    test('Too short', () => expect(() => NpyParser().checkMagicString([147, 78, 85, 77, 80]), returnsNormally));
    test('Too long', () => expect(() => NpyParser().checkMagicString([147, 78, 85, 77, 80, 89, 90]), returnsNormally));
    test('From valid text', () => expect(() => NpyParser().checkMagicString('\x93NUMPY'.codeUnits), returnsNormally));
  });

  group('Parse version:', () {
    test('Create instance with major: 1, minor: 0', () {
      final version = NpyVersion.fromBytes([1, 0]);
      expect(version.major, 1);
      expect(version.minor, 0);
      expect(version.numberOfHeaderBytes, 2);
    });
    test('Create instance with major: 2, minor: 0', () {
      final version = NpyVersion.fromBytes([2, 0]);
      expect(version.major, 2);
      expect(version.minor, 0);
      expect(version.numberOfHeaderBytes, 4);
    });
    test('Create instance with major: 3, minor: 0', () {
      final version = NpyVersion.fromBytes([3, 0]);
      expect(version.major, 3);
      expect(version.minor, 0);
      expect(version.numberOfHeaderBytes, 4);
    });
    test('Insufficient byte length', () => expect(() => NpyVersion.fromBytes([1]), throwsA(isA<AssertionError>())));
    test('Exceeded byte length', () => expect(() => NpyVersion.fromBytes([1, 0, 0]), throwsA(isA<AssertionError>())));
    test('Create instance: Unsupported major version: 0', () {
      expect(() => NpyVersion.fromBytes([0, 0]), throwsA(const TypeMatcher<NpyUnsupportedVersionException>()));
    });
    test('Create instance: Unsupported major version: 4', () {
      expect(() => NpyVersion.fromBytes([4, 0]), throwsA(const TypeMatcher<NpyUnsupportedVersionException>()));
    });
    test('Create instance: Unsupported minor version', () {
      expect(() => NpyVersion.fromBytes([1, 1]), throwsA(const TypeMatcher<NpyUnsupportedVersionException>()));
    });
    test('Parse major: 1, minor: 0', () {
      final parser = NpyParser();
      parser.getVersion([...magicString.codeUnits, 1, 0]);
      expect(parser.version?.major, 1);
      expect(parser.version?.minor, 0);
      expect(parser.version?.numberOfHeaderBytes, 2);
    });
    test('Parse major: 2, minor: 0', () {
      final parser = NpyParser();
      parser.getVersion([...magicString.codeUnits, 2, 0]);
      expect(parser.version?.major, 2);
      expect(parser.version?.minor, 0);
      expect(parser.version?.numberOfHeaderBytes, 4);
    });
    test('Parse major: 3, minor: 0', () {
      final parser = NpyParser();
      parser.getVersion([...magicString.codeUnits, 3, 0]);
      expect(parser.version?.major, 3);
      expect(parser.version?.minor, 0);
      expect(parser.version?.numberOfHeaderBytes, 4);
    });
    test('Unsupported major version in parse', () {
      expect(
        () => NpyParser().getVersion([...magicString.codeUnits, 4, 0]),
        throwsA(const TypeMatcher<NpyUnsupportedVersionException>()),
      );
    });
    test('Unsupported minor version in parse', () {
      expect(
        () => NpyParser().getVersion([...magicString.codeUnits, 1, 1]),
        throwsA(const TypeMatcher<NpyUnsupportedVersionException>()),
      );
    });
    test('Additional bytes', () {
      final parser = NpyParser();
      parser.getVersion([...magicString.codeUnits, 1, 0, 0]);
      expect(parser.version?.major, 1);
      expect(parser.version?.minor, 0);
      expect(parser.version?.numberOfHeaderBytes, 2);
    });
    test('Insufficient bytes', () {
      final parser = NpyParser();
      parser.getVersion([...magicString.codeUnits, 1]);
      expect(parser.version, null);
    });
    test('Second run gets ignored', () {
      final parser = NpyParser();
      parser.getVersion([...magicString.codeUnits, 1, 0]);
      expect(parser.version?.major, 1);
      expect(parser.version?.minor, 0);
      expect(parser.version?.numberOfHeaderBytes, 2);
      parser.getVersion([...magicString.codeUnits, 2, 0]);
      expect(parser.version?.major, 1);
      expect(parser.version?.minor, 0);
      expect(parser.version?.numberOfHeaderBytes, 2);
    });
  });

  group('Parse header length', () {
    test('[2, 1]', () => expect(littleEndian16ToInt([2, 1]), 258));
    test('[4, 3, 2, 1]', () => expect(littleEndian32ToInt([4, 3, 2, 1]), 16909060));
    test('[1, 2, 3, 4]', () => expect(littleEndian32ToInt([1, 2, 3, 4]), 67305985));
    test('Less than 2 bytes', () => expect(() => littleEndian16ToInt([1]), throwsA(isA<AssertionError>())));
    test('Exceed 2 bytes', () => expect(() => littleEndian16ToInt([1, 2, 3]), throwsA(isA<AssertionError>())));
    test('Less than 4 bytes', () => expect(() => littleEndian32ToInt([1, 2, 3]), throwsA(isA<AssertionError>())));
    test('Exceed 4 bytes', () => expect(() => littleEndian32ToInt([1, 2, 3, 3, 4]), throwsA(isA<AssertionError>())));
    test('[2, 1] through parser', () {
      final parser = NpyParser(version: const NpyVersion());
      parser.getHeaderSize([...magicString.codeUnits, ...parser.version!.asBytes, 2, 1]);
      expect(parser.headerSize, 258);
    });
    test('[1, 2] through parser', () {
      final parser = NpyParser(version: const NpyVersion());
      parser.getHeaderSize([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2]);
      expect(parser.headerSize, 513);
    });
    test('Ignore parsing less than 2 bytes', () {
      final parser = NpyParser(version: const NpyVersion());
      parser.getHeaderSize([...magicString.codeUnits, ...parser.version!.asBytes, 1]);
      expect(parser.headerSize, null);
    });
    test('Ignore additional bytes after 2', () {
      final parser = NpyParser(version: const NpyVersion());
      parser.getHeaderSize([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2, 3]);
      expect(parser.headerSize, 513);
    });
    test('[4, 3, 2, 1] through parser', () {
      final parser = NpyParser(version: const NpyVersion(major: 2));
      parser.getHeaderSize([...magicString.codeUnits, ...parser.version!.asBytes, 4, 3, 2, 1]);
      expect(parser.headerSize, 16909060);
    });
    test('[1, 2, 3, 4] through parser', () {
      final parser = NpyParser(version: const NpyVersion(major: 2));
      parser.getHeaderSize([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2, 3, 4]);
      expect(parser.headerSize, 67305985);
    });
    test('Ignore parsing less than 4 bytes', () {
      final parser = NpyParser(version: const NpyVersion(major: 2));
      parser.getHeaderSize([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2, 3]);
      expect(parser.headerSize, null);
    });
    test('Ignore additional bytes after 4', () {
      final parser = NpyParser(version: const NpyVersion(major: 2));
      parser.getHeaderSize([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2, 3, 4, 5]);
      expect(parser.headerSize, 67305985);
    });
    test('Ignore second run', () {
      final parser = NpyParser(version: const NpyVersion());
      parser.getHeaderSize([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2]);
      expect(parser.headerSize, 513);
      parser.getHeaderSize([...magicString.codeUnits, ...parser.version!.asBytes, 3, 3]);
      expect(parser.headerSize, 513);
    });
    test('Return early if version not set', () {
      final parser = NpyParser();
      parser.getHeaderSize([...magicString.codeUnits, ...'\x93NUMPY'.codeUnits, 1, 2]);
      expect(parser.headerSize, null);
    });
    test('[0x56, 0x78]', () {
      final bytes = [0x56, 0x78];
      expect(littleEndian16ToInt(bytes), 0x7856);
      expect(littleEndian16ToInt(bytes), 30806);
    });
    test('[0x78, 0x56]', () {
      final bytes = [0x78, 0x56];
      expect(littleEndian16ToInt(bytes), 0x5678);
      expect(littleEndian16ToInt(bytes), 22136);
    });
    test('[0x12, 0x34, 0x56, 0x78]', () {
      final bytes = [0x12, 0x34, 0x56, 0x78];
      expect(littleEndian32ToInt(bytes), 0x78563412);
      expect(littleEndian32ToInt(bytes), 2018915346);
    });
    test('[0x78, 0x56, 0x34, 0x12]', () {
      final bytes = [0x78, 0x56, 0x34, 0x12];
      expect(littleEndian32ToInt(bytes), 0x12345678);
      expect(littleEndian32ToInt(bytes), 305419896);
    });
  });

  group('Parse NpyEndian:', () {
    test('Little endian', () => expect(NpyEndian.fromChar('<'), NpyEndian.little));
    test('Big endian', () => expect(NpyEndian.fromChar('>'), NpyEndian.big));
    test('Native byte', () => expect(NpyEndian.fromChar('='), NpyEndian.native));
    test('None', () => expect(NpyEndian.fromChar('|'), NpyEndian.none));
    test('Invalid endian', () {
      expect(() => NpyEndian.fromChar('!'), throwsA(const TypeMatcher<NpyUnsupportedEndianException>()));
    });
    test('Empty string', () => expect(() => NpyEndian.fromChar(''), throwsA(isA<AssertionError>())));
    test('Two characters', () => expect(() => NpyEndian.fromChar('<>'), throwsA(isA<AssertionError>())));
  });

  group('Parse NpyType:', () {
    test('Boolean type', () => expect(NpyType.fromChar('?'), NpyType.boolean));
    test('Byte type', () => expect(NpyType.fromChar('b'), NpyType.byte));
    test('Unsigned byte type', () => expect(NpyType.fromChar('B'), NpyType.uByte));
    test('Integer type', () => expect(NpyType.fromChar('i'), NpyType.int));
    test('Unsigned integer type', () => expect(NpyType.fromChar('u'), NpyType.uint));
    test('Float type', () => expect(NpyType.fromChar('f'), NpyType.float));
    test('Complex type', () => expect(NpyType.fromChar('c'), NpyType.complex));
    test('Time delta type', () => expect(NpyType.fromChar('m'), NpyType.timeDelta));
    test('Date time type', () => expect(NpyType.fromChar('M'), NpyType.dateTime));
    test('Object type', () => expect(NpyType.fromChar('O'), NpyType.object));
    test("String type, 'S' representation", () => expect(NpyType.fromChar('S'), NpyType.string));
    test("String type, 'a' representation", () => expect(NpyType.fromChar('a'), NpyType.string));
    test('Unicode type', () => expect(NpyType.fromChar('U'), NpyType.unicode));
    test('Void type', () => expect(NpyType.fromChar('V'), NpyType.voidType));
    test('Invalid type', () {
      expect(() => NpyType.fromChar('x'), throwsA(const TypeMatcher<NpyUnsupportedNpyTypeException>()));
    });
    test('Empty string', () => expect(() => NpyType.fromChar(''), throwsA(isA<AssertionError>())));
    test('Two characters', () => expect(() => NpyType.fromChar('fc'), throwsA(isA<AssertionError>())));
  });

  group('Match NpyType:', () {
    test('Boolean type', () {
      const type = NpyType.boolean;
      expect(type.matches('?'), true);
      expect(type.matches('b'), false);
    });
    test('Float type', () {
      const type = NpyType.float;
      expect(type.matches('f'), true);
      expect(type.matches('i'), false);
    });
    test('String type', () {
      const type = NpyType.string;
      expect(type.matches('S'), true);
      expect(type.matches('a'), true);
      expect(type.matches('U'), false);
    });
  });

  group('Parse NpyDType:', () {
    test('<f8', () {
      final dtype = NpyDType.fromString('<f8');
      expect(dtype.endian, NpyEndian.little);
      expect(dtype.type, NpyType.float);
      expect(dtype.itemSize, 8);
    });
    test('>i4', () {
      final dtype = NpyDType.fromString('>i4');
      expect(dtype.endian, NpyEndian.big);
      expect(dtype.type, NpyType.int);
      expect(dtype.itemSize, 4);
    });
    test('|S10', () {
      final dtype = NpyDType.fromString('|S10');
      expect(dtype.endian, NpyEndian.none);
      expect(dtype.type, NpyType.string);
      expect(dtype.itemSize, 10);
    });
    test('=u2', () {
      final dtype = NpyDType.fromString('=u2');
      expect(dtype.endian, NpyEndian.native);
      expect(dtype.type, NpyType.uint);
      expect(dtype.itemSize, 2);
    });
    test('Empty string', () {
      expect(() => NpyDType.fromString(''), throwsA(const TypeMatcher<NpyInvalidDTypeException>()));
    });
    test('Unsufficient length', () {
      expect(() => NpyDType.fromString('<f'), throwsA(const TypeMatcher<NpyInvalidDTypeException>()));
    });
    test('Invalid descr', () {
      expect(() => NpyDType.fromString('f>8'), throwsA(const TypeMatcher<NpyInvalidDTypeException>()));
    });
    test('Invalid endian', () {
      expect(() => NpyDType.fromString('!f8'), throwsA(const TypeMatcher<NpyInvalidDTypeException>()));
    });
    test('Invalid type', () {
      expect(() => NpyDType.fromString('|X8'), throwsA(const TypeMatcher<NpyInvalidDTypeException>()));
    });
    test('Invalid digit', () {
      expect(() => NpyDType.fromString('>ff'), throwsA(const TypeMatcher<NpyInvalidDTypeException>()));
    });
  });

  group('Get shape:', () {
    test('Empty list', () {
      final header = NpyHeader.fromList([]);
      expect(header.shape, []);
      expect(header.dtype.type, NpyType.float);
    });
    test('One int', () {
      final header = NpyHeader.fromList([42]);
      expect(header.shape, [1]);
      expect(header.dtype.type, NpyType.int);
    });
    test('Two ints', () {
      final header = NpyHeader.fromList([42, 35]);
      expect(header.shape, [2]);
      expect(header.dtype.type, NpyType.int);
    });
    test('Two doubles', () {
      final header = NpyHeader.fromList([0.1, 2.3]);
      expect(header.shape, [2]);
      expect(header.dtype.type, NpyType.float);
    });
    test('[2, 3]', () {
      final header = NpyHeader.fromList([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(header.shape, [2, 3]);
      expect(header.dtype.type, NpyType.int);
    });
    test('[3, 2, 1]', () {
      final header = NpyHeader.fromList([
        [
          [1.0],
          [2.1],
        ],
        [
          [3.2],
          [4.3],
        ],
        [
          [5.4],
          [6.5],
        ],
      ]);
      expect(header.shape, [3, 2, 1]);
      expect(header.dtype.type, NpyType.float);
    });
    test('[2, 0]', () {
      final header = NpyHeader.fromList([
        [],
        [],
      ]);
      expect(header.shape, [2, 0]);
      expect(header.dtype.type, NpyType.float);
    });
    test('[true, false, true]', () {
      final header = NpyHeader.fromList([true, false, true]);
      expect(header.shape, [3]);
    });
    test('[[true, false, true], [false, true, false]]', () {
      final header = NpyHeader.fromList([
        [true, false, true],
        [false, true, false],
      ]);
      expect(header.shape, [2, 3]);
    });
    test('String throws error', () {
      expect(() => NpyHeader.fromList(['hi']), throwsA(const TypeMatcher<NpyUnsupportedTypeException>()));
    });
  });

  group('Parse NpyHeader:', () {
    test('Empty header', () {
      expect(() => NpyHeader.fromBytes(''.codeUnits), throwsA(const TypeMatcher<NpyInvalidHeaderException>()));
    });
    test('Only curly braces', () {
      expect(() => NpyHeader.fromBytes('{}'.codeUnits), throwsA(const TypeMatcher<NpyInvalidHeaderException>()));
    });
    test('Something random', () {
      expect(() => NpyHeader.fromBytes('xyz'.codeUnits), throwsA(const TypeMatcher<NpyInvalidHeaderException>()));
    });
    test('<f8, False, (3,)', () {
      final header = NpyHeader.fromBytes("{'descr': '<f8', 'fortran_order': False, 'shape': (3,)}".codeUnits);
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, false);
      expect(header.shape, [3]);
    });
    test('<f8, True, (3,)', () {
      final header = NpyHeader.fromBytes("{'descr': '<f8', 'fortran_order': True, 'shape': (3,)}".codeUnits);
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [3]);
    });
    test('<f8, null, (3,)', () {
      expect(
        () => NpyHeader.fromBytes("{'descr': '<f8', 'fortran_order': null, 'shape': (3,)}".codeUnits),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
    test('>i4, True, (3,)', () {
      final header = NpyHeader.fromBytes("{'descr': '>i4', 'fortran_order': True, 'shape': (3,)}".codeUnits);
      expect(header.dtype.endian, NpyEndian.big);
      expect(header.dtype.type, NpyType.int);
      expect(header.dtype.itemSize, 4);
      expect(header.fortranOrder, true);
      expect(header.shape, [3]);
    });
    test('|S200, True, (3,)', () {
      final header = NpyHeader.fromBytes("{'descr': '|S200', 'fortran_order': True, 'shape': (3,)}".codeUnits);
      expect(header.dtype.endian, NpyEndian.none);
      expect(header.dtype.type, NpyType.string);
      expect(header.dtype.itemSize, 200);
      expect(header.fortranOrder, true);
      expect(header.shape, [3]);
    });
    test('<x4, True, (3,)', () {
      expect(
        () => NpyHeader.fromBytes("{'descr': '<x4', 'fortran_order': True, 'shape': (3,)}".codeUnits),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
    test('Missing descr', () {
      expect(
        () => NpyHeader.fromBytes("{'fortran_order': True, 'shape': (3,)}".codeUnits),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
    test('Missing fortran_order', () {
      expect(
        () => NpyHeader.fromBytes("{'descr': '<f8', 'shape': (3,)}".codeUnits),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
    test('Missing shape', () {
      expect(
        () => NpyHeader.fromBytes("{'descr': '<f8', 'fortran_order': True}".codeUnits),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
    test('<f8, True, ()', () {
      final header = NpyHeader.fromBytes("{'descr': '<f8', 'fortran_order': True, 'shape': ()}".codeUnits);
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, []);
    });
    test('<f8, True, (2, 3)', () {
      final header = NpyHeader.fromBytes("{'descr': '<f8', 'fortran_order': True, 'shape': (2, 3)}".codeUnits);
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3]);
    });
    test('<f8, True, (2, 3) with extra whitespace', () {
      final header =
          NpyHeader.fromBytes("{' descr' :  '<f8 ' ,  ' fortran_order ':  True ,  ' shape' :  ( 2 , 3 ) }".codeUnits);
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3]);
    });
    test('<f8, True, (2, 3) with whitespace and trailing comma', () {
      final header =
          NpyHeader.fromBytes("{'descr' :'<f8 ' , ' fortran_order ':  True ,  ' shape' :  ( 2 , 3 ) , }".codeUnits);
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3]);
    });
    test('<f8, True, (2, 3, 4)', () {
      final header = NpyHeader.fromBytes("{'descr': '<f8', 'fortran_order': True, 'shape': (2, 3, 4)}".codeUnits);
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3, 4]);
    });
    test('Invalid shape', () {
      expect(
        () => NpyHeader.fromBytes("{'descr': '<f8', 'fortran_order': True, 'shape': [2, 3]}".codeUnits),
        throwsA(const TypeMatcher<NpyInvalidHeaderException>()),
      );
    });
  });

  group('Parse header section:', () {
    test('Build section when data is available', () {
      List<int> bytes = const [];
      final parser = NpyParser()
        ..checkMagicString(bytes)
        ..getVersion(bytes)
        ..getHeaderSize(bytes)
        ..getHeader(bytes)
        ..buildHeaderSection();
      expect(parser.headerSection, null);
      bytes = [...magicString.codeUnits];
      parser
        ..checkMagicString(bytes)
        ..getVersion(bytes)
        ..getHeaderSize(bytes)
        ..getHeader(bytes)
        ..buildHeaderSection();
      expect(parser.hasPassedMagicStringCheck, true);
      expect(parser.headerSection, null);
      bytes = [...bytes, 1, 0];
      parser
        ..checkMagicString(bytes)
        ..getVersion(bytes)
        ..getHeaderSize(bytes)
        ..getHeader(bytes)
        ..buildHeaderSection();
      expect(parser.version?.major, 1);
      expect(parser.version?.minor, 0);
      expect(parser.version?.numberOfHeaderBytes, 2);
      expect(parser.headerSection, null);
      final headerSection = NpyHeaderSection.fromList([1, 2, 3]);
      bytes = [...bytes, ...headerSection.headerSizeAsBytes];
      parser
        ..checkMagicString(bytes)
        ..getVersion(bytes)
        ..getHeaderSize(bytes)
        ..getHeader(bytes)
        ..buildHeaderSection();
      expect(parser.headerSize, 118);
      expect(parser.headerSection, null);
      expect(parser.isNotReadyForData, true);
      bytes = [...bytes, ...headerSection.header.asBytes];
      parser
        ..checkMagicString(bytes)
        ..getVersion(bytes)
        ..getHeaderSize(bytes)
        ..getHeader(bytes)
        ..buildHeaderSection();
      expect(parser.header?.length, 118);
      expect(parser.headerSection?.size, 128);
      expect(parser.isNotReadyForData, false);
    });
  });

  group('Parse bytes:', () {
    test('1 little endian float64', () {
      final header = NpyHeader.fromList([1.0], dtype: const NpyDType.float64(endian: NpyEndian.little));
      final data = parseBytes([0, 0, 0, 0, 0, 0, 240, 63], header);
      expect(data, [1.0]);
    });
    test('2 big endian float32', () {
      final header = NpyHeader.fromList([0.9, -0.2], dtype: const NpyDType.float32(endian: NpyEndian.big));
      final data = parseBytes<double>([63, 102, 102, 102, 190, 76, 204, 205], header);
      expect(listAlmostEquals(data, [0.9, -0.2]), true);
    });
    test('2 little endian int64', () {
      final header = NpyHeader.fromList([-42, 2], dtype: const NpyDType.int64(endian: NpyEndian.little));
      final data = parseBytes([214, 255, 255, 255, 255, 255, 255, 255, 2, 0, 0, 0, 0, 0, 0, 0], header);
      expect(data, [-42, 2]);
    });
    test('1 big endian int32', () {
      final header = NpyHeader.fromList([1], dtype: const NpyDType.int32(endian: NpyEndian.big));
      final data = parseBytes([0, 0, 0, 1], header);
      expect(data, [1]);
    });
    test('2 little endian int16', () {
      final header = NpyHeader.fromList([1, 2], dtype: const NpyDType.int16(endian: NpyEndian.little));
      final data = parseBytes([1, 0, 2, 0], header);
      expect(data, [1, 2]);
    });
    test('4 int8', () {
      final header = NpyHeader.fromList([1, -1, 3, 4], dtype: const NpyDType.int8());
      final data = parseBytes([1, 255, 3, 4], header);
      expect(data, [1, -1, 3, 4]);
    });
    test('1 big endian uint64', () {
      final header = NpyHeader.fromList([1], dtype: const NpyDType.uint64(endian: NpyEndian.big));
      final data = parseBytes([0, 0, 0, 0, 0, 0, 0, 1], header);
      expect(data, [1]);
    });
    test('2 little endian uint32', () {
      final header = NpyHeader.fromList([1, 2], dtype: const NpyDType.uint32(endian: NpyEndian.little));
      final data = parseBytes([1, 0, 0, 0, 2, 0, 0, 0], header);
      expect(data, [1, 2]);
    });
    test('1 big endian uint16', () {
      final header = NpyHeader.fromList([1], dtype: const NpyDType.uint16(endian: NpyEndian.big));
      final data = parseBytes([0, 1], header);
      expect(data, [1]);
    });
    test('3 uint8', () {
      final header = NpyHeader.fromList([1, 255, 3], dtype: const NpyDType.uint8());
      final data = parseBytes([1, 255, 3], header);
      expect(data, [1, 255, 3]);
    });
    test('1D bool', () {
      final header = NpyHeader.fromList([true, false, true]);
      expect(parseBytes([1, 0, 1], header), [true, false, true]);
    });
    test('2D bool', () {
      final header = NpyHeader.fromList([
        [true, false, true],
        [false, true, false],
      ]);
      expect(parseBytes([1, 0, 1, 0, 1, 0], header), [
        [true, false, true],
        [false, true, false],
      ]);
    });
  });

  group('Reshape:', () {
    test('Empty list', () => expect(reshape([], []), []));
    test(
      'Empty shape',
      () => expect(() => reshape([1, 2, 3, 4, 5, 6], []), throwsA(const TypeMatcher<NpyParseException>())),
    );
    test('1D int', () => expect(reshape([1, 2, 3, 4, 5, 6], [6]), [1, 2, 3, 4, 5, 6]));
    test('2D int', () {
      expect(reshape([1, 2, 3, 4, 5, 6], [2, 3]), [
        [1, 2, 3],
        [4, 5, 6],
      ]);
    });
    test('2D int reverse', () {
      expect(reshape([1, 2, 3, 4, 5, 6], [3, 2]), [
        [1, 2],
        [3, 4],
        [5, 6],
      ]);
    });
    test('2D int, single row', () {
      expect(reshape([1, 2, 3, 4, 5, 6], [1, 6]), [
        [1, 2, 3, 4, 5, 6],
      ]);
    });
    test('2D int, single column', () {
      expect(reshape([1, 2, 3, 4, 5, 6], [6, 1]), [
        [1],
        [2],
        [3],
        [4],
        [5],
        [6],
      ]);
    });
    test('3D int', () {
      expect(reshape([1, 2, 3, 4, 5, 6], [1, 2, 3]), [
        [
          [1, 2, 3],
          [4, 5, 6],
        ],
      ]);
    });
    test('2D float', () {
      expect(reshape([1.0, 2.1, 3.2, 4.3, 5.4, 6.5], [2, 3]), [
        [1.0, 2.1, 3.2],
        [4.3, 5.4, 6.5],
      ]);
    });
    test(
      'List length does not match shape',
      () => expect(() => reshape([1, 2, 3, 4], [5]), throwsA(const TypeMatcher<NpyParseException>())),
    );
    test('Empty list, fortran oder', () => expect(reshape([], [], fortranOrder: true), []));
    test(
      'Empty shape, fortran order',
      () => expect(
        () => reshape([1, 2, 3, 4, 5, 6], [], fortranOrder: true),
        throwsA(const TypeMatcher<NpyParseException>()),
      ),
    );
    test(
      '1D int, fortran order',
      () => expect(reshape([1, 2, 3, 4, 5, 6], [6], fortranOrder: true), [1, 2, 3, 4, 5, 6]),
    );
    test('2D int, fortran order', () {
      expect(reshape([1, 4, 2, 5, 3, 6], [2, 3], fortranOrder: true), [
        [1, 2, 3],
        [4, 5, 6],
      ]);
    });
    test('2D int reverse, fortran order', () {
      expect(reshape([1, 3, 5, 2, 4, 6], fortranOrder: true, [3, 2]), [
        [1, 2],
        [3, 4],
        [5, 6],
      ]);
    });
    test('2D int, single row, fortran order', () {
      expect(reshape([1, 2, 3, 4, 5, 6], fortranOrder: true, [1, 6]), [
        [1, 2, 3, 4, 5, 6],
      ]);
    });
    test('2D int, single column, fortran order', () {
      expect(reshape([1, 2, 3, 4, 5, 6], fortranOrder: true, [6, 1]), [
        [1],
        [2],
        [3],
        [4],
        [5],
        [6],
      ]);
    });
    test('3D int, fortran order', () {
      expect(
          reshape(
            [1, 13, 5, 17, 9, 21, 2, 14, 6, 18, 10, 22, 3, 15, 7, 19, 11, 23, 4, 16, 8, 20, 12, 24],
            [2, 3, 4],
            fortranOrder: true,
          ),
          [
            [
              [1, 2, 3, 4],
              [5, 6, 7, 8],
              [9, 10, 11, 12],
            ],
            [
              [13, 14, 15, 16],
              [17, 18, 19, 20],
              [21, 22, 23, 24],
            ],
          ]);
    });
    test('2D float, fortran order', () {
      expect(reshape([1.0, 4.3, 2.1, 5.4, 3.2, 6.5], fortranOrder: true, [2, 3]), [
        [1.0, 2.1, 3.2],
        [4.3, 5.4, 6.5],
      ]);
    });
    test(
      'List length does not match shape',
      () => expect(() => reshape([1, 2, 3, 4], [5]), throwsA(const TypeMatcher<NpyParseException>())),
    );
  });

  group('Load npy:', () {
    test('Non-existent file', () {
      expect(load('not_existent.npy'), throwsA(const TypeMatcher<NpFileNotExistsException>()));
    });
    test('Pointing at current directory', () => expect(load('.'), throwsA(const TypeMatcher<NpFileOpenException>())));
    test('Empty file', () async {
      const filename = 'empty_file.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([]);
      await expectLater(load(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    test('Insufficient length', () async {
      const filename = 'insufficient_length.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([1, 2, 3]);
      await expectLater(load(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    test('Invalid magic string', () async {
      const filename = 'invalid_magic_string.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([1, 2, 3, 4, 5, 6]);
      await expectLater(load(filename), throwsA(const TypeMatcher<NpyInvalidMagicStringException>()));
      tmpFile.deleteSync();
    });
    test('Unsupported major version', () async {
      const filename = 'unsupported_major_version.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 4, 0]);
      await expectLater(load(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    test('Unsupported minor version', () async {
      const filename = 'unsupported_minor_version.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 1, 1]);
      await expectLater(load(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    test('Empty list', () async {
      const filename = 'empty_list.tmp';
      final headerSection = NpyHeaderSection.fromList([]);
      final tmpFile = File(filename)..writeAsBytesSync(headerSection.asBytes);
      final ndarray = await load(filename);
      expect(ndarray.headerSection.header.dtype.endian, NpyEndian.little);
      expect(ndarray.headerSection.header.dtype.type, NpyType.float);
      expect(ndarray.headerSection.header.dtype.itemSize, 8);
      expect(ndarray.headerSection.header.fortranOrder, false);
      expect(ndarray.headerSection.header.shape, const []);
      expect(ndarray.data, const []);
      tmpFile.deleteSync();
    });
    test('float list', () async {
      const filename = 'float_list.tmp';
      final headerSection = NpyHeaderSection.fromList([1.0, -2.1]);
      final tmpFile = File(filename)
        ..writeAsBytesSync([...headerSection.asBytes, 0, 0, 0, 0, 0, 0, 240, 63, 205, 204, 204, 204, 204, 204, 0, 192]);
      final ndarray = await load(filename);
      expect(ndarray.headerSection.header.dtype.endian, NpyEndian.little);
      expect(ndarray.headerSection.header.dtype.type, NpyType.float);
      expect(ndarray.headerSection.header.dtype.itemSize, 8);
      expect(ndarray.headerSection.header.fortranOrder, false);
      expect(ndarray.headerSection.header.shape, [2]);
      expect(ndarray.data, [1.0, -2.1]);
      tmpFile.deleteSync();
    });
    test('int list', () async {
      const filename = 'int_list.tmp';
      final headerSection = NpyHeaderSection.fromList([-1, 1]);
      final tmpFile = File(filename)
        ..writeAsBytesSync([...headerSection.asBytes, 255, 255, 255, 255, 255, 255, 255, 255, 1, 0, 0, 0, 0, 0, 0, 0]);
      final ndarray = await load(filename);
      expect(ndarray.headerSection.header.shape, [2]);
      expect(ndarray.data, [-1, 1]);
      tmpFile.deleteSync();
    });
    test('uint list', () async {
      const filename = 'uint_list.tmp';
      final headerSection = NpyHeaderSection.fromList([1, 1], dtype: const NpyDType.uint32());
      final tmpFile = File(filename)..writeAsBytesSync([...headerSection.asBytes, 255, 255, 255, 255, 1, 0, 0, 0]);
      final ndarray = await load(filename);
      expect(ndarray.headerSection.header.dtype.type, NpyType.uint);
      expect(ndarray.headerSection.header.shape, [2]);
      expect(ndarray.data, [4294967295, 1]);
      tmpFile.deleteSync();
    });
    test('2d int list', () async {
      const filename = '2d_int_list.tmp';
      final headerSection = NpyHeaderSection.fromList(
        [
          [1, 2, 3],
          [4, 5, 6],
        ],
        dtype: const NpyDType.int16(),
      );
      final tmpFile = File(filename)..writeAsBytesSync([...headerSection.asBytes, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0]);
      final ndarray = await load(filename);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      expect(ndarray.headerSection.header.dtype.itemSize, 2);
      expect(ndarray.headerSection.header.shape, [2, 3]);
      expect(ndarray.data, [
        [1, 2, 3],
        [4, 5, 6],
      ]);
      tmpFile.deleteSync();
    });
    test('bool list', () async {
      const filename = 'bool_list.tmp';
      final headerSection = NpyHeaderSection.fromList([true, false]);
      final tmpFile = File(filename)..writeAsBytesSync([...headerSection.asBytes, 1, 0]);
      final ndarray = await load(filename);
      expect(ndarray.headerSection.header.shape, [2]);
      expect(ndarray.data, [true, false]);
      tmpFile.deleteSync();
    });
    // test('np.array(0)', () async {
    //   await load('test/files/array_0.npy');
    //   // expect(load('test/array_0.npy'), throwsA(const TypeMatcher<int>()));
    // });
  });

  group('Get padding size:', () {
    test('0', () => expect(getPaddingSize(0), 0));
    test('1', () => expect(getPaddingSize(1), 63));
    test('63', () => expect(getPaddingSize(63), 1));
    test('64', () => expect(getPaddingSize(64), 0));
    test('65', () => expect(getPaddingSize(65), 63));
  });

  group('Cannot be ASCII endoded:', () {
    test('Empty String', () => expect(NpyVersion.cannotBeAsciiEncoded(''), false));
    test('Blank space', () => expect(NpyVersion.cannotBeAsciiEncoded(' '), false));
    test('abc', () => expect(NpyVersion.cannotBeAsciiEncoded('abc'), false));
    test('~', () => expect(NpyVersion.cannotBeAsciiEncoded('~'), false));
    test('\x79', () => expect(NpyVersion.cannotBeAsciiEncoded('\x79'), false));
    test('\x80', () => expect(NpyVersion.cannotBeAsciiEncoded('\x80'), true));
    test('€', () => expect(NpyVersion.cannotBeAsciiEncoded('€'), true));
    test('42.50 €', () => expect(NpyVersion.cannotBeAsciiEncoded('42.50 €'), true));
  });

  group('Build header string:', () {
    test('<f8, False, ()', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType.float64(endian: NpyEndian.little),
        fortranOrder: false,
        shape: [],
      );
      expect(header.string, "{'descr': '<f8', 'fortran_order': False, 'shape': (), }");
    });
    test('<f8, True, ()', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType.float64(endian: NpyEndian.little),
        fortranOrder: true,
        shape: [],
      );
      expect(header.string, "{'descr': '<f8', 'fortran_order': True, 'shape': (), }");
    });
    test('>i4, True, ()', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType.int32(endian: NpyEndian.big),
        fortranOrder: true,
        shape: [],
      );
      expect(header.string, "{'descr': '>i4', 'fortran_order': True, 'shape': (), }");
    });
    test('<i2, True, (3,)', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType.int16(endian: NpyEndian.little),
        fortranOrder: true,
        shape: [3],
      );
      expect(header.string, "{'descr': '<i2', 'fortran_order': True, 'shape': (3,), }");
    });
    test('>f4, True, (3, 4)', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType.float32(endian: NpyEndian.big),
        fortranOrder: true,
        shape: [3, 4],
      );
      expect(header.string, "{'descr': '>f4', 'fortran_order': True, 'shape': (3, 4), }");
    });
  });

  group('Header size to bytes:', () {
    test('Empty list', () {
      final bytes = NpyHeaderSection.fromList([]).headerSizeAsBytes;
      expect(bytes.length, 2);
      expect(bytes[0], 118);
      expect(bytes[1], 0);
    });
    // test('100, V2', () {
    //   final bytes = NpyHeaderSection(
    //     version: const NpyVersion(major: 2),
    //     header: NpyHeader.fromList([]),
    //     headerSize: 0,
    //     paddingSize: 0,
    //   ).headerSizeAsBytes(100);
    //   expect(bytes.length, 4);
    //   expect(bytes[0], 100);
    //   expect(bytes[1], 0);
    //   expect(bytes[2], 0);
    //   expect(bytes[3], 0);
    // });
    // test('65536, V2', () {
    //   final bytes = NpyHeaderSection(
    //     version: const NpyVersion(major: 2),
    //     header: NpyHeader.fromList([]),
    //     headerSize: 0,
    //     paddingSize: 0,
    //   ).headerSizeAsBytes(65536);
    //   expect(bytes.length, 4);
    //   expect(bytes[0], 0);
    //   expect(bytes[1], 0);
    //   expect(bytes[2], 1);
    //   expect(bytes[3], 0);
    // });
    // test('V2 max', () {
    //   final bytes = NpyHeaderSection(
    //     version: const NpyVersion(major: 2),
    //     header: NpyHeader.fromList([]),
    //     headerSize: 0,
    //     paddingSize: 0,
    //   ).headerSizeAsBytes(4294967295);
    //   expect(bytes.length, 4);
    //   expect(bytes[0], 255);
    //   expect(bytes[1], 255);
    //   expect(bytes[2], 255);
    //   expect(bytes[3], 255);
    // });
    // test('V2 exceeded', () {
    //   final bytes = NpyHeaderSection(
    //     version: const NpyVersion(major: 2),
    //     header: NpyHeader.fromList([]),
    //     headerSize: 0,
    //     paddingSize: 0,
    //   );
    //   expect(() => bytes.headerSizeAsBytes(4294967296), throwsA(isA<AssertionError>()));
    // });
  });

  group('Flatten:', () {
    test('Empty list, C order', () => expect(flattenCOrder([]), []));
    test('1D int, C order', () => expect(flattenCOrder([1, 2, 3, 4, 5, 6]), [1, 2, 3, 4, 5, 6]));
    test('1D int, C order, expect int', () => expect(flattenCOrder<int>([1, 2, 3]), [1, 2, 3]));
    test('1D int, C order, expect wrong type', () => expect(() => flattenCOrder<bool>([1]), throwsA(isA<TypeError>())));
    test(
      '2D int, C order',
      () => expect(
        flattenCOrder([
          [1, 2, 3],
          [4, 5, 6],
        ]),
        [1, 2, 3, 4, 5, 6],
      ),
    );
    test(
      '3D int, C order',
      () => expect(
        flattenCOrder([
          [
            [1, 2],
            [3, 4],
          ],
          [
            [5, 6],
            [7, 8],
          ]
        ]),
        [1, 2, 3, 4, 5, 6, 7, 8],
      ),
    );
    test(
      '3D int, C order, expect int',
      () => expect(
        flattenCOrder<int>([
          [
            [1, 2],
            [3, 4],
          ],
          [
            [5, 6],
            [7, 8],
          ]
        ]),
        [1, 2, 3, 4, 5, 6, 7, 8],
      ),
    );
    test('Empty list, Fortran order', () => expect(flattenFortranOrder([], shape: []), []));
    test(
      '1D int, Fortran order',
      () => expect(flattenFortranOrder([1, 2, 3, 4, 5, 6], shape: [6]), [1, 2, 3, 4, 5, 6]),
    );
    test(
      '1D int, Fortran order, expect int',
      () => expect(flattenFortranOrder<int>([1, 2, 3, 4, 5, 6], shape: [6]), [1, 2, 3, 4, 5, 6]),
    );
    test(
      '1D int, Fortran order, expect wrong type',
      () => expect(() => flattenFortranOrder<double>([1], shape: [1]), throwsA(isA<TypeError>())),
    );
    test(
      '2D int, Fortran order',
      () => expect(
        flattenFortranOrder(
          [
            [1, 2, 3],
            [4, 5, 6],
          ],
          shape: [2, 3],
        ),
        [1, 4, 2, 5, 3, 6],
      ),
    );
    test(
      '2D bool, Fortran order',
      () => expect(
        flattenFortranOrder(
          [
            [false, false, false],
            [true, true, true],
          ],
          shape: [2, 3],
        ),
        [false, true, false, true, false, true],
      ),
    );
    test(
      '2D float, Fortran order',
      () => expect(
        flattenFortranOrder(
          [
            [1.1, 2.2],
            [3.3, 4.4],
            [5.5, 6.6],
          ],
          shape: [3, 2],
        ),
        [1.1, 3.3, 5.5, 2.2, 4.4, 6.6],
      ),
    );
    test('3D int, fortran order', () {
      expect(
        flattenFortranOrder(
          [
            [
              [1, 2, 3, 4],
              [5, 6, 7, 8],
              [9, 10, 11, 12],
            ],
            [
              [13, 14, 15, 16],
              [17, 18, 19, 20],
              [21, 22, 23, 24],
            ],
          ],
          shape: [2, 3, 4],
        ),
        [1, 13, 5, 17, 9, 21, 2, 14, 6, 18, 10, 22, 3, 15, 7, 19, 11, 23, 4, 16, 8, 20, 12, 24],
      );
    });
    test('3D int, fortran order, expect int', () {
      expect(
        flattenFortranOrder<int>(
          [
            [
              [1, 2, 3, 4],
              [5, 6, 7, 8],
              [9, 10, 11, 12],
            ],
            [
              [13, 14, 15, 16],
              [17, 18, 19, 20],
              [21, 22, 23, 24],
            ],
          ],
          shape: [2, 3, 4],
        ),
        [1, 13, 5, 17, 9, 21, 2, 14, 6, 18, 10, 22, 3, 15, 7, 19, 11, 23, 4, 16, 8, 20, 12, 24],
      );
    });
  });

  group('NdArray to bytes:', () {
    test('[]', () {
      final ndarray = NdArray.fromList(const []);
      expect(ndarray.data, const []);
      expect(ndarray.headerSection.header.dtype.type, NpyType.float);
      expect(ndarray.dataBytes.length, 0);
    });
    test('[], uint', () {
      final ndarray = NdArray.fromList(const [], dtype: const NpyDType.uint64());
      expect(ndarray.data, const []);
      expect(ndarray.headerSection.header.dtype.type, NpyType.uint);
      expect(ndarray.dataBytes.length, 0);
    });
    test('[1]', () {
      final ndarray = NdArray.fromList(const [1]);
      expect(ndarray.data, const [1]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 8);
      expect(dataBytes.first, 1);
    });
    test('[-1]', () {
      final ndarray = NdArray.fromList(const [-1]);
      expect(ndarray.data, const [-1]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 8);
      expect(dataBytes.first, 255);
      expect(dataBytes.last, 255);
    });
    test('[1, 200]', () {
      final ndarray = NdArray.fromList(const [1, 200]);
      expect(ndarray.data, const [1, 200]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 16);
      expect(dataBytes.elementAt(0), 1);
      expect(dataBytes.elementAt(1), 0);
      expect(dataBytes.elementAt(8), 200);
      expect(dataBytes.elementAt(9), 0);
    });
    test('[1.0]', () {
      final ndarray = NdArray.fromList(const [1.0]);
      expect(ndarray.data, const [1.0]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.float);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 8);
      expect(dataBytes.first, 0);
      expect(dataBytes.elementAt(5), 0);
      expect(dataBytes.elementAt(6), 0xf0);
      expect(dataBytes.last, 0x3f);
    });
    test('[256], big endian', () {
      final ndarray = NdArray.fromList(const [256], endian: NpyEndian.big);
      expect(ndarray.data, const [256]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 8);
      expect(dataBytes.first, 0);
      expect(dataBytes.elementAt(6), 1);
      expect(dataBytes.last, 0);
    });
    test('[1, 200], big endian', () {
      final ndarray = NdArray.fromList(const [1, 200], endian: NpyEndian.big);
      expect(ndarray.data, const [1, 200]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 16);
      expect(dataBytes.elementAt(7), 1);
      expect(dataBytes.elementAt(6), 0);
      expect(dataBytes.elementAt(15), 200);
      expect(dataBytes.elementAt(14), 0);
    });
    test('[1.0, 1.9], big endian', () {
      final ndarray = NdArray.fromList(const [1.0, 1.9], endian: NpyEndian.big);
      expect(ndarray.data, const [1.0, 1.9]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.float);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 16);
      expect(dataBytes.first, 0x3f);
      expect(dataBytes.elementAt(1), 0xf0);
      expect(dataBytes.elementAt(2), 0);
      expect(dataBytes.elementAt(8), 0x3f);
      expect(dataBytes.elementAt(9), 0xfe);
      expect(dataBytes.last, 0x66);
    });
    test('[1, 200]', () {
      final ndarray = NdArray.fromList(const [1, 200], dtype: const NpyDType.int32());
      expect(ndarray.data, const [1, 200]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 8);
      expect(dataBytes.first, 1);
      expect(dataBytes.elementAt(1), 0);
      expect(dataBytes.elementAt(4), 200);
      expect(dataBytes.elementAt(5), 0);
    });
    test('[1, 200], big endian', () {
      final ndarray = NdArray.fromList(const [1, 200], dtype: const NpyDType.int32(endian: NpyEndian.big));
      expect(ndarray.data, const [1, 200]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 8);
      expect(dataBytes.first, 0);
      expect(dataBytes.elementAt(2), 0);
      expect(dataBytes.elementAt(3), 1);
      expect(dataBytes.elementAt(6), 0);
      expect(dataBytes.last, 200);
    });
    test('[0.5, 2.0]', () {
      final ndarray = NdArray.fromList(const [0.5, 2.0], dtype: const NpyDType.float32(endian: NpyEndian.little));
      expect(ndarray.data, const [0.5, 2.0]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.float);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 8);
      expect(dataBytes.first, 0);
      expect(dataBytes.elementAt(2), 0);
      expect(dataBytes.elementAt(3), 0x3f);
      expect(dataBytes.elementAt(6), 0);
      expect(dataBytes.elementAt(7), 0x40);
    });
    test('2d, shape [2, 1], little endian, C order', () {
      final ndarray = NdArray.fromList(const [
        [1],
        [200],
      ]);
      expect(ndarray.data, const [
        [1],
        [200],
      ]);
      expect(ndarray.headerSection.header.shape, [2, 1]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 16);
      expect(dataBytes.first, 1);
      expect(dataBytes.elementAt(1), 0);
      expect(dataBytes.elementAt(8), 200);
      expect(dataBytes.elementAt(9), 0);
    });
    test('2d, shape [1, 2], little endian, C order', () {
      final ndarray = NdArray.fromList(const [
        [1, 200],
      ]);
      expect(ndarray.data, const [
        [1, 200],
      ]);
      expect(ndarray.headerSection.header.shape, [1, 2]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 16);
      expect(dataBytes.first, 1);
      expect(dataBytes.elementAt(1), 0);
      expect(dataBytes.elementAt(8), 200);
      expect(dataBytes.elementAt(9), 0);
    });
    test('2d, shape [2, 3], little endian, C order', () {
      final ndarray = NdArray.fromList(const [
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(ndarray.data, const [
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(ndarray.headerSection.header.shape, [2, 3]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 48);
      expect(dataBytes.first, 1);
      expect(dataBytes.elementAt(1), 0);
      expect(dataBytes.elementAt(8), 2);
      expect(dataBytes.elementAt(9), 0);
      expect(dataBytes.elementAt(16), 3);
      expect(dataBytes.elementAt(24), 4);
      expect(dataBytes.elementAt(32), 5);
      expect(dataBytes.elementAt(40), 6);
    });
    test('2d, shape [2, 3], little endian, Fortran order', () {
      final ndarray = NdArray.fromList(
        const [
          [1, 2, 3],
          [4, 5, 6],
        ],
        fortranOrder: true,
      );
      expect(ndarray.data, const [
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(ndarray.headerSection.header.shape, [2, 3]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 48);
      expect(dataBytes.first, 1);
      expect(dataBytes.elementAt(1), 0);
      expect(dataBytes.elementAt(8), 4);
      expect(dataBytes.elementAt(9), 0);
      expect(dataBytes.elementAt(16), 2);
      expect(dataBytes.elementAt(24), 5);
      expect(dataBytes.elementAt(32), 3);
      expect(dataBytes.elementAt(40), 6);
    });
    test('2d, shape [2, 3], big endian, Fortran order', () {
      final ndarray = NdArray.fromList(
        const [
          [1, 2, 3],
          [4, 5, 6],
        ],
        endian: NpyEndian.big,
        fortranOrder: true,
      );
      expect(ndarray.data, const [
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(ndarray.headerSection.header.shape, [2, 3]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 48);
      expect(dataBytes.first, 0);
      expect(dataBytes.elementAt(7), 1);
      expect(dataBytes.elementAt(15), 4);
      expect(dataBytes.elementAt(16), 0);
      expect(dataBytes.elementAt(23), 2);
      expect(dataBytes.elementAt(31), 5);
      expect(dataBytes.elementAt(39), 3);
      expect(dataBytes.elementAt(47), 6);
    });
    test('3d, shape [2, 3, 4], little endian, C order', () {
      final ndarray = NdArray.fromList(
        [
          [
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [9, 10, 11, 12],
          ],
          [
            [13, 14, 15, 16],
            [17, 18, 19, 20],
            [21, 22, 23, 24],
          ],
        ],
      );
      expect(
        ndarray.data,
        [
          [
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [9, 10, 11, 12],
          ],
          [
            [13, 14, 15, 16],
            [17, 18, 19, 20],
            [21, 22, 23, 24],
          ],
        ],
      );
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      expect(ndarray.headerSection.header.shape, [2, 3, 4]);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 192);
      expect(dataBytes.first, 1);
      expect(dataBytes.elementAt(1), 0);
      expect(dataBytes.elementAt(8), 2);
      expect(dataBytes.elementAt(9), 0);
      expect(dataBytes.elementAt(16), 3);
      expect(dataBytes.elementAt(24), 4);
      expect(dataBytes.elementAt(32), 5);
      expect(dataBytes.elementAt(40), 6);
      expect(dataBytes.elementAt(176), 23);
      expect(dataBytes.elementAt(184), 24);
    });
    test('3d, shape [2, 3, 4], big endian, Fortran order', () {
      final ndarray = NdArray.fromList(
        [
          [
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [9, 10, 11, 12],
          ],
          [
            [13, 14, 15, 16],
            [17, 18, 19, 20],
            [21, 22, 23, 24],
          ],
        ],
        endian: NpyEndian.big,
        fortranOrder: true,
      );
      expect(
        ndarray.data,
        [
          [
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [9, 10, 11, 12],
          ],
          [
            [13, 14, 15, 16],
            [17, 18, 19, 20],
            [21, 22, 23, 24],
          ],
        ],
      );
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      expect(ndarray.headerSection.header.shape, [2, 3, 4]);
      final dataBytes = ndarray.dataBytes;
      expect(dataBytes.length, 192);
      expect(dataBytes.first, 0);
      expect(dataBytes.elementAt(1), 0);
      expect(dataBytes.elementAt(7), 1);
      expect(dataBytes.elementAt(15), 13);
      expect(dataBytes.elementAt(23), 5);
      expect(dataBytes.elementAt(31), 17);
      expect(dataBytes.elementAt(39), 9);
      expect(dataBytes.elementAt(47), 21);
      expect(dataBytes.elementAt(55), 2);
      expect(dataBytes.elementAt(183), 12);
      expect(dataBytes.elementAt(191), 24);
    });
  });

  group('Save list:', () {
    test('Empty list', () async {
      const filename = 'save_empty_list.tmp';
      await saveList(filename, const []);
      final bytes = File(filename).readAsBytesSync();
      expect(bytes.length, 128);
      File(filename).delete();
      final headerSection = NpyHeaderSection.fromHeader(NpyHeader.fromBytes(bytes));
      expect(headerSection.header.fortranOrder, false);
      expect(headerSection.header.dtype.endian, NpyEndian.little);
      expect(headerSection.header.dtype.type, NpyType.float);
      expect(headerSection.header.dtype.itemSize, 8);
      expect(headerSection.header.shape, const []);
    });
    test('1d bool', () async {
      const filename = 'save_1d_bool.tmp';
      await saveList(filename, [true, false]);
      final bytes = File(filename).readAsBytesSync();
      File(filename).delete();
      final headerSection = NpyHeaderSection.fromHeader(NpyHeader.fromBytes(bytes.sublist(0, 128)));
      expect(headerSection.header.fortranOrder, false);
      expect(headerSection.header.dtype.endian, NpyEndian.none);
      expect(headerSection.header.dtype.type, NpyType.boolean);
      expect(headerSection.header.dtype.itemSize, 1);
      expect(headerSection.header.shape, [2]);
      expect(bytes.sublist(128), [1, 0]);
    });
    test('2d float', () async {
      const filename = 'save_2d_float.tmp';
      await saveList(filename, [
        [1.0, 2.0],
        [3.0, 4.0],
        [5.0, 6.0],
      ]);
      final bytes = File(filename).readAsBytesSync();
      File(filename).delete();
      final headerSection = NpyHeaderSection.fromHeader(NpyHeader.fromBytes(bytes.sublist(0, 128)));
      expect(headerSection.header.fortranOrder, false);
      expect(headerSection.header.dtype.endian, NpyEndian.little);
      expect(headerSection.header.dtype.type, NpyType.float);
      expect(headerSection.header.dtype.itemSize, 8);
      expect(headerSection.header.shape, [3, 2]);
      expect(
        bytes.sublist(128),
        [
          0,
          0,
          0,
          0,
          0,
          0,
          0xf0,
          0x3f,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0x40,
          0,
          0,
          0,
          0,
          0,
          0,
          0x08,
          0x40,
          0,
          0,
          0,
          0,
          0,
          0,
          0x10,
          0x40,
          0,
          0,
          0,
          0,
          0,
          0,
          0x14,
          0x40,
          0,
          0,
          0,
          0,
          0,
          0,
          0x18,
          0x40,
        ],
      );
    });
    test('3d int16, big endian, Fortran order', () async {
      const filename = 'save_3d_int16.tmp';
      await saveList(
        filename,
        [
          [
            [1, 2, 3],
            [4, 5, 6],
          ],
          [
            [7, 8, 9],
            [10, 11, 12],
          ],
        ],
        dtype: const NpyDType.int16(endian: NpyEndian.big),
        fortranOrder: true,
      );
      final bytes = File(filename).readAsBytesSync();
      File(filename).delete();
      final headerSection = NpyHeaderSection.fromHeader(NpyHeader.fromBytes(bytes.sublist(0, 128)));
      expect(headerSection.header.dtype.type, NpyType.int);
      expect(headerSection.header.dtype.endian, NpyEndian.big);
      expect(headerSection.header.fortranOrder, true);
      expect(headerSection.header.dtype.itemSize, 2);
      expect(headerSection.header.shape, [2, 2, 3]);
      expect(bytes.sublist(128), [0, 1, 0, 7, 0, 4, 0, 10, 0, 2, 0, 8, 0, 5, 0, 11, 0, 3, 0, 9, 0, 6, 0, 12]);
    });
  });

  group('Save:', () {
    test('1d float', () async {
      const filename = 'save_1d_float.tmp';
      await save(filename, NdArray.fromList(const [-1.0, 2.2, -4.2]));
      final bytes = File(filename).readAsBytesSync();
      File(filename).delete();
      final headerSection = NpyHeaderSection.fromHeader(NpyHeader.fromBytes(bytes.sublist(0, 128)));
      expect(headerSection.header.fortranOrder, false);
      expect(headerSection.header.dtype.endian, NpyEndian.little);
      expect(headerSection.header.dtype.type, NpyType.float);
      expect(headerSection.header.dtype.itemSize, 8);
      expect(headerSection.header.shape, [3]);
      expect(bytes.sublist(128), [
        0,
        0,
        0,
        0,
        0,
        0,
        0xf0,
        0xbf,
        0x9a,
        0x99,
        0x99,
        0x99,
        0x99,
        0x99,
        0x01,
        0x40,
        0xcd,
        0xcc,
        0xcc,
        0xcc,
        0xcc,
        0xcc,
        0x10,
        0xc0,
      ]);
    });
    test('3d uint16, big endian, Fortran order', () async {
      const filename = 'save_3d_uint.tmp';
      await save(
        filename,
        NdArray.fromList(
          [
            [
              [1, 2],
              [3, 4],
              [5, 6],
            ],
            [
              [7, 8],
              [9, 10],
              [11, 12],
            ],
          ],
          dtype: const NpyDType.uint16(endian: NpyEndian.big),
          fortranOrder: true,
        ),
      );
      final bytes = File(filename).readAsBytesSync();
      File(filename).delete();
      final headerSection = NpyHeaderSection.fromHeader(NpyHeader.fromBytes(bytes.sublist(0, 128)));
      expect(headerSection.header.dtype.type, NpyType.uint);
      expect(headerSection.header.dtype.endian, NpyEndian.big);
      expect(headerSection.header.fortranOrder, true);
      expect(headerSection.header.dtype.itemSize, 2);
      expect(headerSection.header.shape, [2, 3, 2]);
      expect(bytes.sublist(128), [0, 1, 0, 7, 0, 3, 0, 9, 0, 5, 0, 11, 0, 2, 0, 8, 0, 4, 0, 10, 0, 6, 0, 12]);
    });
  });
}
