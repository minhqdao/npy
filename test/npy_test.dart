import 'dart:io';

import 'package:npy/npy.dart';
import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';
import 'package:test/test.dart';

void main() {
  group('Check magic string:', () {
    test(
      'Valid code units',
      () => expect(() => NpyHeaderSection().checkMagicString([147, 78, 85, 77, 80, 89]), returnsNormally),
    );
    test(
      'Invalid first byte',
      () => expect(
        () => NpyHeaderSection().checkMagicString([146, 78, 85, 77, 80, 89]),
        throwsA(const TypeMatcher<NpyInvalidMagicStringException>()),
      ),
    );
    test(
      'Invalid last byte',
      () => expect(
        () => NpyHeaderSection().checkMagicString([147, 78, 85, 77, 80, 87]),
        throwsA(const TypeMatcher<NpyInvalidMagicStringException>()),
      ),
    );
    test('Too short', () => expect(() => NpyHeaderSection().checkMagicString([147, 78, 85, 77, 80]), returnsNormally));
    test(
      'Too long',
      () => expect(() => NpyHeaderSection().checkMagicString([147, 78, 85, 77, 80, 89, 90]), returnsNormally),
    );
    test(
      'From valid text',
      () => expect(() => NpyHeaderSection().checkMagicString('\x93NUMPY'.codeUnits), returnsNormally),
    );
  });

  group('Parse NpyVersion:', () {
    test('Major: 1, Minor: 0', () {
      final version = NpyVersion.fromBytes([1, 0]);
      expect(version.major, 1);
      expect(version.minor, 0);
    });
    test('Major: 2, Minor: 0', () {
      final version = NpyVersion.fromBytes([2, 0]);
      expect(version.major, 2);
      expect(version.minor, 0);
    });
    test('Major: 3, Minor: 0', () {
      final version = NpyVersion.fromBytes([3, 0]);
      expect(version.major, 3);
      expect(version.minor, 0);
    });
    test('Unsupported major version', () {
      expect(() => NpyVersion.fromBytes([4, 0]), throwsA(const TypeMatcher<NpyUnsupportedVersionException>()));
    });
    test('Unsupported minor version', () {
      expect(() => NpyVersion.fromBytes([1, 1]), throwsA(const TypeMatcher<NpyUnsupportedVersionException>()));
    });
    test('Major: 1, Minor: 0 in header section', () {
      final headerSection = NpyHeaderSection(version: NpyVersion.fromBytes([1, 0]));
      expect(headerSection.version!.major, 1);
      expect(headerSection.version!.minor, 0);
      expect(headerSection.numberOfHeaderBytes, 2);
    });
    test('Major: 2, Minor: 0 in header section', () {
      final headerSection = NpyHeaderSection(version: NpyVersion.fromBytes([2, 0]));
      expect(headerSection.version!.major, 2);
      expect(headerSection.version!.minor, 0);
      expect(headerSection.numberOfHeaderBytes, 4);
    });
    test('Major: 3, Minor: 0 in header section', () {
      final headerSection = NpyHeaderSection(version: NpyVersion.fromBytes([3, 0]));
      expect(headerSection.version!.major, 3);
      expect(headerSection.version!.minor, 0);
      expect(headerSection.numberOfHeaderBytes, 4);
    });
    test('Unsupported major version in header', () {
      expect(
        () => NpyHeaderSection(version: NpyVersion.fromBytes([4, 0])),
        throwsA(const TypeMatcher<NpyUnsupportedVersionException>()),
      );
    });
    test('Unsupported minor version in header', () {
      expect(
        () => NpyHeaderSection(version: NpyVersion.fromBytes([1, 1])),
        throwsA(const TypeMatcher<NpyUnsupportedVersionException>()),
      );
    });
  });

  group('Parse header length', () {
    test('[2, 1]', () => expect(littleEndian16ToInt([2, 1]), 258));
    test('[1, 2]', () => expect(littleEndian16ToInt([1, 2]), 513));
    test('[4, 3, 2, 1]', () => expect(littleEndian32ToInt([4, 3, 2, 1]), 16909060));
    test('[1, 2, 3, 4]', () => expect(littleEndian32ToInt([1, 2, 3, 4]), 67305985));
    test(
      '[2, 1] from getLength',
      () => expect(NpyHeaderSection(version: const NpyVersion()).getHeaderLength([2, 1]), 258),
    );
    test(
      '[1, 2] from getLength',
      () => expect(NpyHeaderSection(version: const NpyVersion()).getHeaderLength([1, 2]), 513),
    );
    test(
      '[4, 3, 2, 1] from getLength',
      () => expect(NpyHeaderSection(version: const NpyVersion(major: 2)).getHeaderLength([4, 3, 2, 1]), 16909060),
    );
    test(
      '[1, 2, 3, 4] from getLength',
      () => expect(NpyHeaderSection(version: const NpyVersion(major: 2)).getHeaderLength([1, 2, 3, 4]), 67305985),
    );
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
      expect(() => NpyType.fromChar('a'), throwsA(const TypeMatcher<NpyUnsupportedNpyTypeException>()));
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
      expect(dtype.itemSize, 8);
    });
    test('>f4', () {
      final dtype = NpyDType.fromString('>f4');
      expect(dtype.byteOrder, NpyByteOrder.bigEndian);
      expect(dtype.kind, NpyType.float);
      expect(dtype.itemSize, 4);
    });
    test('|S10', () {
      final dtype = NpyDType.fromString('|S10');
      expect(dtype.byteOrder, NpyByteOrder.none);
      expect(dtype.kind, NpyType.string);
      expect(dtype.itemSize, 10);
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
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, false);
      expect(header.shape, [3]);
    });
    test('<f8, True, (3,)', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (3,)}");
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
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
      expect(header.dtype.byteOrder, NpyByteOrder.bigEndian);
      expect(header.dtype.kind, NpyType.int);
      expect(header.dtype.itemSize, 4);
      expect(header.fortranOrder, true);
      expect(header.shape, [3]);
    });
    test('|S200, True, (3,)', () {
      final header = NpyHeader.fromString("{'descr': '|S200', 'fortran_order': True, 'shape': (3,)}");
      expect(header.dtype.byteOrder, NpyByteOrder.none);
      expect(header.dtype.kind, NpyType.string);
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
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, []);
    });
    test('<f8, True, (2, 3)', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (2, 3)}");
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3]);
    });
    test('<f8, True, (2, 3) with extra whitespace', () {
      final header = NpyHeader.fromString("{' descr' :  '<f8 ' ,  ' fortran_order ':  True ,  ' shape' :  ( 2 , 3 ) }");
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3]);
    });
    test('<f8, True, (2, 3) with whitespace and trailing comma', () {
      final header = NpyHeader.fromString("{'descr' :'<f8 ' , ' fortran_order ':  True ,  ' shape' :  ( 2 , 3 ) , }");
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
      expect(header.dtype.itemSize, 8);
      expect(header.fortranOrder, true);
      expect(header.shape, [2, 3]);
    });
    test('<f8, True, (2, 3, 4)', () {
      final header = NpyHeader.fromString("{'descr': '<f8', 'fortran_order': True, 'shape': (2, 3, 4)}");
      expect(header.dtype.byteOrder, NpyByteOrder.littleEndian);
      expect(header.dtype.kind, NpyType.float);
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
    test('Pointing at current directory', () {
      expect(load('.'), throwsA(const TypeMatcher<NpFileOpenException>()));
    });
    test('Empty file', () {
      const filename = 'empty_file.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([]);
      expect(load(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    test('Insufficient length', () {
      const filename = 'insufficient_length.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([1, 2, 3]);
      expect(load(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    test('Invalid magic string', () {
      const filename = 'invalid_magic_string.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([1, 2, 3, 4, 5, 6]);
      expect(load(filename), throwsA(const TypeMatcher<NpyInvalidMagicStringException>()));
      tmpFile.deleteSync();
    });
    test('Unsupported major version', () {
      const filename = 'unsupported_major_version.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 4, 0]);
      expect(load(filename), throwsA(const TypeMatcher<NpyParseException>()));
      tmpFile.deleteSync();
    });
    test('Unsupported minor version', () {
      const filename = 'unsupported_minor_version.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 1, 1]);
      expect(load(filename), throwsA(const TypeMatcher<NpyParseException>()));
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
    //   expect(npyFile.header.dtype.byteOrder, NpyByteOrder.littleEndian);
    //   expect(npyFile.header.dtype.kind, NpyType.float);
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
    //   expect(npyFile.header.dtype.byteOrder, NpyByteOrder.littleEndian);
    //   expect(npyFile.header.dtype.kind, NpyType.float);
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
    //   expect(npyFile.header.dtype.byteOrder, NpyByteOrder.littleEndian);
    //   expect(npyFile.header.dtype.kind, NpyType.float);
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
    //   expect(npyFile.header.dtype.byteOrder, NpyByteOrder.bigEndian);
    //   expect(npyFile.header.dtype.kind, NpyType.int);
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
    //   expect(npyFile.header.dtype.byteOrder, NpyByteOrder.bigEndian);
    //   expect(npyFile.header.dtype.kind, NpyType.int);
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
  group('Build header string:', () {
    test('<f8, False, ()', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType(byteOrder: NpyByteOrder.littleEndian, kind: NpyType.float, itemSize: 8),
        fortranOrder: false,
        shape: [],
      );
      expect(header.string, "{'descr': '<f8', 'fortran_order': False, 'shape': (), }");
    });
    test('<f8, True, ()', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType(byteOrder: NpyByteOrder.littleEndian, kind: NpyType.float, itemSize: 8),
        fortranOrder: true,
        shape: [],
      );
      expect(header.string, "{'descr': '<f8', 'fortran_order': True, 'shape': (), }");
    });
    test('>i4, True, ()', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType(byteOrder: NpyByteOrder.bigEndian, kind: NpyType.int, itemSize: 4),
        fortranOrder: true,
        shape: [],
      );
      expect(header.string, "{'descr': '>i4', 'fortran_order': True, 'shape': (), }");
    });
    test('<i2, True, (3,)', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType(byteOrder: NpyByteOrder.littleEndian, kind: NpyType.int, itemSize: 2),
        fortranOrder: true,
        shape: [3],
      );
      expect(header.string, "{'descr': '<i2', 'fortran_order': True, 'shape': (3,), }");
    });
    test('>f4, True, (3, 4)', () {
      final header = NpyHeader.buildString(
        dtype: const NpyDType(byteOrder: NpyByteOrder.bigEndian, kind: NpyType.float, itemSize: 4),
        fortranOrder: true,
        shape: [3, 4],
      );
      expect(header.string, "{'descr': '>f4', 'fortran_order': True, 'shape': (3, 4), }");
    });
  });
  group('Save npy:', () {
    test('Save empty list', () async {
      const filename = 'save_empty_list.tmp';
      await saveList(filename, []);
      // final ndarray = await load(filename);
      // expect(ndarray.headerSection.version?.major, 1);
      // expect(ndarray.headerSection.version?.minor, 0);
      // expect(ndarray.data, []);
      File(filename).deleteSync();
    });
  });
}
