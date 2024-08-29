import 'dart:io';

import 'package:collection/collection.dart';
import 'package:npy/npy.dart';
import 'package:npy/src/np_exception.dart';
import 'package:test/test.dart';

void main() {
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
      parser.getHeaderLength([...magicString.codeUnits, ...parser.version!.asBytes, 2, 1]);
      expect(parser.headerLength, 258);
    });
    test('[1, 2] through parser', () {
      final parser = NpyParser(version: const NpyVersion());
      parser.getHeaderLength([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2]);
      expect(parser.headerLength, 513);
    });
    test('Ignore parsing less than 2 bytes', () {
      final parser = NpyParser(version: const NpyVersion());
      parser.getHeaderLength([...magicString.codeUnits, ...parser.version!.asBytes, 1]);
      expect(parser.headerLength, null);
    });
    test('Ignore additional bytes after 2', () {
      final parser = NpyParser(version: const NpyVersion());
      parser.getHeaderLength([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2, 3]);
      expect(parser.headerLength, 513);
    });
    test('[4, 3, 2, 1] through parser', () {
      final parser = NpyParser(version: const NpyVersion(major: 2));
      parser.getHeaderLength([...magicString.codeUnits, ...parser.version!.asBytes, 4, 3, 2, 1]);
      expect(parser.headerLength, 16909060);
    });
    test('[1, 2, 3, 4] through parser', () {
      final parser = NpyParser(version: const NpyVersion(major: 2));
      parser.getHeaderLength([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2, 3, 4]);
      expect(parser.headerLength, 67305985);
    });
    test('Ignore parsing less than 4 bytes', () {
      final parser = NpyParser(version: const NpyVersion(major: 2));
      parser.getHeaderLength([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2, 3]);
      expect(parser.headerLength, null);
    });
    test('Ignore additional bytes after 4', () {
      final parser = NpyParser(version: const NpyVersion(major: 2));
      parser.getHeaderLength([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2, 3, 4, 5]);
      expect(parser.headerLength, 67305985);
    });
    test('Ignore second run', () {
      final parser = NpyParser(version: const NpyVersion());
      parser.getHeaderLength([...magicString.codeUnits, ...parser.version!.asBytes, 1, 2]);
      expect(parser.headerLength, 513);
      parser.getHeaderLength([...magicString.codeUnits, ...parser.version!.asBytes, 3, 3]);
      expect(parser.headerLength, 513);
    });
    test('Return early if version not set', () {
      final parser = NpyParser();
      parser.getHeaderLength([...magicString.codeUnits, ...'\x93NUMPY'.codeUnits, 1, 2]);
      expect(parser.headerLength, null);
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
    test('Boolean type', () => expect(NpyType.fromChar('b'), NpyType.boolean));
    test('Integer type', () => expect(NpyType.fromChar('i'), NpyType.int));
    test('Unsigned integer type', () => expect(NpyType.fromChar('u'), NpyType.uint));
    test('Float type', () => expect(NpyType.fromChar('f'), NpyType.float));
    test('Complex type', () => expect(NpyType.fromChar('c'), NpyType.complex));
    test('String type', () => expect(NpyType.fromChar('S'), NpyType.string));
    test('Unicode type', () => expect(NpyType.fromChar('U'), NpyType.unicode));
    test('Void type', () => expect(NpyType.fromChar('V'), NpyType.voidType));
    test('Invalid type', () {
      expect(() => NpyType.fromChar('a'), throwsA(const TypeMatcher<NpyUnsupportedNpyTypeException>()));
    });
    test('Empty string', () => expect(() => NpyType.fromChar(''), throwsA(isA<AssertionError>())));
    test('Two characters', () => expect(() => NpyType.fromChar('fc'), throwsA(isA<AssertionError>())));
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
  group('ListProperties:', () {
    test('Empty list', () {
      final header = NpyHeader.fromList([]);
      expect(const ListEquality().equals(header.shape, []), true);
      expect(header.dtype.type, NpyType.float);
    });
    test('One int', () {
      final header = NpyHeader.fromList([42]);
      expect(const ListEquality().equals(header.shape, [1]), true);
      expect(header.dtype.type, NpyType.int);
    });
    test('Two ints', () {
      final header = NpyHeader.fromList([42, 35]);
      expect(const ListEquality().equals(header.shape, [2]), true);
      expect(header.dtype.type, NpyType.int);
    });
    test('Two doubles', () {
      final header = NpyHeader.fromList([0.1, 2.3]);
      expect(const ListEquality().equals(header.shape, [2]), true);
      expect(header.dtype.type, NpyType.float);
    });
    test('[2, 3]', () {
      final header = NpyHeader.fromList([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(const ListEquality().equals(header.shape, [2, 3]), true);
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
      expect(const ListEquality().equals(header.shape, [3, 2, 1]), true);
      expect(header.dtype.type, NpyType.float);
    });
    test('[2, 0]', () {
      final header = NpyHeader.fromList([
        [],
        [],
      ]);
      expect(const ListEquality().equals(header.shape, [2, 0]), true);
      expect(header.dtype.type, NpyType.float);
    });
    test('Bool throws error', () {
      expect(() => NpyHeader.fromList([true]), throwsA(const TypeMatcher<NpyUnsupportedTypeException>()));
    });
    test('String throws error', () {
      expect(() => NpyHeader.fromList(['hi']), throwsA(const TypeMatcher<NpyUnsupportedTypeException>()));
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
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, false);
      expect(header.shape, [3]);
    });
    test('<f8, True, (3,)', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (3,)}");
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
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
      expect(header.dtype.endian, NpyEndian.big);
      expect(header.dtype.type, NpyType.int);
      expect(header.dtype.itemSize, 4);
      expect(header.fortranOrder, true);
      expect(header.shape, [3]);
    });
    test('|S200, True, (3,)', () {
      final header = NpyHeader.fromString("{'descr': '|S200', 'fortran_order': True, 'shape': (3,)}");
      expect(header.dtype.endian, NpyEndian.none);
      expect(header.dtype.type, NpyType.string);
      expect(header.dtype.itemSize, 200);
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
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, []);
    });
    test('<f8, True, (2, 3)', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (2, 3)}");
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3]);
    });
    test('<f8, True, (2, 3) with extra whitespace', () {
      final header = NpyHeader.fromString("{' descr' :  '<f8 ' ,  ' fortran_order ':  True ,  ' shape' :  ( 2 , 3 ) }");
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3]);
    });
    test('<f8, True, (2, 3) with whitespace and trailing comma', () {
      final header = NpyHeader.fromString("{'descr' :'<f8 ' , ' fortran_order ':  True ,  ' shape' :  ( 2 , 3 ) , }");
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3]);
    });
    test('<f8, True, (2, 3, 4)', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (2, 3, 4)}");
      expect(header.dtype.endian, NpyEndian.little);
      expect(header.dtype.type, NpyType.float);
      expect(header.dtype.itemSize, 8);
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
    // test('Header 1', () async {
    //   const filename = 'header_1.tmp';
    //   final headerSection = NpyHeaderSection(
    //     version: const NpyVersion(),
    //     header: NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': ()}"),
    //   );
    //   final tmpFile = File(filename)..writeAsBytesSync(headerSection.asBytes);
    //   final npyFile = await load(filename);
    //   expect(npyFile.header.dtype.endian, NpyEndian.little);
    //   expect(npyFile.header.dtype.type, NpyType.float);
    //   expect(npyFile.header.dtype.itemSize, 8);
    //   expect(npyFile.header.fortranOrder, true);
    //   expect(npyFile.header.shape, []);
    //   tmpFile.deleteSync();
    // });
    // test('Header 2', () async {
    //   const filename = 'header_2.tmp';
    //   final headerSection = NpyHeaderSection(
    //     version: const NpyVersion(),
    //     header: NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (3,)}"),
    //   );
    //   final tmpFile = File(filename)..writeAsBytesSync(headerSection.asBytes);
    //   final npyFile = await load(filename);
    //   expect(npyFile.header.dtype.endian, NpyEndian.little);
    //   expect(npyFile.header.dtype.type, NpyType.float);
    //   expect(npyFile.header.dtype.itemSize, 8);
    //   expect(npyFile.header.fortranOrder, true);
    //   expect(npyFile.header.shape, [3]);
    //   tmpFile.deleteSync();
    // });
    // test('Header 3', () async {
    //   const filename = 'header_3.tmp';
    //   final headerSection = NpyHeaderSection.fromString("{'descr': '<f8', 'fortran_order': False, 'shape': (3,), }");
    //   File(filename).writeAsBytesSync(headerSection.asBytes);
    // });
    // test('Header 3', () async {
    //   const filename = 'header_3.tmp';
    //   const version = NpyVersion();
    //   final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (3, 4)}");
    //   final tmpFile = File(filename)..writeAsBytesSync(header.getHeaderSection(version: version));
    //   final npyFile = await load(filename);
    //   expect(npyFile.version.major, 1);
    //   expect(npyFile.version.minor, 0);
    //   expect(npyFile.headerLength, 56);
    //   expect(npyFile.header.dtype.endian, NpyEndian.little);
    //   expect(npyFile.header.dtype.type, NpyType.float);
    //   expect(npyFile.header.dtype.itemSize, 8);
    //   expect(npyFile.header.fortranOrder, true);
    //   expect(npyFile.header.shape, [3, 4]);
    //   tmpFile.deleteSync();
    // });
    // test('Header 3', () async {
    //   const filename = 'header_3.tmp';
    //   const majorVersion = 2;
    //   const header = "{'descr': '>i4', 'fortran_order': False, 'shape': (3,4,5)}";
    //   final tmpFile = File(filename)
    //     ..writeAsBytesSync(
    //       [
    //         ...magicString.codeUnits,
    //         majorVersion,
    //         0,
    //         ...NpyHeader.getSizeFromString(header, majorVersion),
    //         ...header.codeUnits,
    //       ],
    //     );
    //   final npyFile = await load(filename);
    //   expect(npyFile.version.major, 2);
    //   expect(npyFile.version.minor, 0);
    //   expect(npyFile.headerLength, 58);
    //   expect(npyFile.header.dtype.endian, NpyEndian.big);
    //   expect(npyFile.header.dtype.type, NpyType.int);
    //   expect(npyFile.header.dtype.itemSize, 4);
    //   expect(npyFile.header.fortranOrder, false);
    //   expect(npyFile.header.shape, [3, 4, 5]);
    //   tmpFile.deleteSync();
    // });
    // test('Header 4', () async {
    //   const filename = 'header_4.tmp';
    //   const majorVersion = 1;
    //   const header = "{'descr': '>i4', 'fortran_order': False, 'shape': ()}";
    //   final tmpFile = File(filename)
    //     ..writeAsBytesSync(
    //       [
    //         ...magicString.codeUnits,
    //         majorVersion,
    //         0,
    //         ...NpyHeader.getSizeFromString(header, majorVersion),
    //         ...header.codeUnits,
    //       ],
    //     );
    //   final npyFile = await load(filename);
    //   expect(npyFile.version.major, 1);
    //   expect(npyFile.version.minor, 0);
    //   expect(npyFile.headerLength, 53);
    //   expect(npyFile.header.dtype.endian, NpyEndian.big);
    //   expect(npyFile.header.dtype.type, NpyType.int);
    //   expect(npyFile.header.dtype.itemSize, 4);
    //   expect(npyFile.header.fortranOrder, false);
    //   expect(npyFile.header.shape, []);
    //   tmpFile.deleteSync();
    // });
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
        dtype: const NpyDType(endian: NpyEndian.little, type: NpyType.float, itemSize: 8),
        fortranOrder: false,
        shape: [],
      );
      expect(header.string, "{'descr': '<f8', 'fortran_order': False, 'shape': (), }");
    });
    test('<f8, True, ()', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType(endian: NpyEndian.little, type: NpyType.float, itemSize: 8),
        fortranOrder: true,
        shape: [],
      );
      expect(header.string, "{'descr': '<f8', 'fortran_order': True, 'shape': (), }");
    });
    test('>i4, True, ()', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType(endian: NpyEndian.big, type: NpyType.int, itemSize: 4),
        fortranOrder: true,
        shape: [],
      );
      expect(header.string, "{'descr': '>i4', 'fortran_order': True, 'shape': (), }");
    });
    test('<i2, True, (3,)', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType(endian: NpyEndian.little, type: NpyType.int, itemSize: 2),
        fortranOrder: true,
        shape: [3],
      );
      expect(header.string, "{'descr': '<i2', 'fortran_order': True, 'shape': (3,), }");
    });
    test('>f4, True, (3, 4)', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType(endian: NpyEndian.big, type: NpyType.float, itemSize: 4),
        fortranOrder: true,
        shape: [3, 4],
      );
      expect(header.string, "{'descr': '>f4', 'fortran_order': True, 'shape': (3, 4), }");
    });
  });
  group('Header size to bytes:', () {
    test('0', () {
      final bytes = NpyHeaderSection.fromList([]).headerSizeBytes(0);
      expect(bytes.length, 2);
      expect(bytes[0], 0);
      expect(bytes[1], 0);
    });
    test('1', () {
      final bytes = NpyHeaderSection.fromList([]).headerSizeBytes(1);
      expect(bytes.length, 2);
      expect(bytes[0], 1);
      expect(bytes[1], 0);
    });
    test('First version maximum', () {
      final bytes = NpyHeaderSection.fromList([]).headerSizeBytes(65535);
      expect(bytes.length, 2);
      expect(bytes[0], 255);
      expect(bytes[1], 255);
    });
    test('Exceeds first version maximum', () {
      expect(() => NpyHeaderSection.fromList([]).headerSizeBytes(65536), throwsA(isA<AssertionError>()));
    });
    test('0, V2', () {
      final bytes = NpyHeaderSection(
        version: const NpyVersion(major: 2),
        numberOfHeaderBytes: 0,
        header: NpyHeader.fromList([]),
        headerLength: 0,
        paddingSize: 0,
      ).headerSizeBytes(0);
      expect(bytes.length, 4);
      expect(bytes[0], 0);
      expect(bytes[1], 0);
      expect(bytes[2], 0);
      expect(bytes[3], 0);
    });
    test('100, V2', () {
      final bytes = NpyHeaderSection(
        version: const NpyVersion(major: 2),
        numberOfHeaderBytes: 0,
        header: NpyHeader.fromList([]),
        headerLength: 0,
        paddingSize: 0,
      ).headerSizeBytes(100);
      expect(bytes.length, 4);
      expect(bytes[0], 100);
      expect(bytes[1], 0);
      expect(bytes[2], 0);
      expect(bytes[3], 0);
    });
    test('65536, V2', () {
      final bytes = NpyHeaderSection(
        version: const NpyVersion(major: 2),
        numberOfHeaderBytes: 0,
        header: NpyHeader.fromList([]),
        headerLength: 0,
        paddingSize: 0,
      ).headerSizeBytes(65536);
      expect(bytes.length, 4);
      expect(bytes[0], 0);
      expect(bytes[1], 0);
      expect(bytes[2], 1);
      expect(bytes[3], 0);
    });
    test('V2 max', () {
      final bytes = NpyHeaderSection(
        version: const NpyVersion(major: 2),
        numberOfHeaderBytes: 0,
        header: NpyHeader.fromList([]),
        headerLength: 0,
        paddingSize: 0,
      ).headerSizeBytes(4294967295);
      expect(bytes.length, 4);
      expect(bytes[0], 255);
      expect(bytes[1], 255);
      expect(bytes[2], 255);
      expect(bytes[3], 255);
    });
    test('V2 exceeded', () {
      final bytes = NpyHeaderSection(
        version: const NpyVersion(major: 2),
        numberOfHeaderBytes: 0,
        header: NpyHeader.fromList([]),
        headerLength: 0,
        paddingSize: 0,
      );
      expect(() => bytes.headerSizeBytes(4294967296), throwsA(isA<AssertionError>()));
    });
  });
  group('NdArray to bytes:', () {
    test('', () {
      final ndarray = NdArray.fromList([]);
      expect(ndarray.asBytes.skip(ndarray.headerSection.length).length, 0);
    });
  });
  group('Save npy:', () {
    test('Save empty list', () async {
      const filename = 'save_empty_list.tmp';
      await saveList(filename, []);
      // final ndarray = await load(filename);
      // expect(ndarray.headerSection.version?.major, 1);
      // expect(ndarray.headerSection.version?.minor, 0);
      // expect(ndarray.list, []);
      File(filename).deleteSync();
    });
  });
}
