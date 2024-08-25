import 'dart:io';

import 'package:npy/npy.dart';
import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';
import 'package:test/test.dart';

void main() {
  group('Magic number:', () {
    test('Valid code units', () => expect(isMagicString([147, 78, 85, 77, 80, 89]), true));
    test('Invalid first byte', () => expect(isMagicString([146, 78, 85, 77, 80, 89]), false));
    test('Invalid last byte', () => expect(isMagicString([147, 78, 85, 77, 80, 87]), false));
    test('Too short', () => expect(isMagicString([147, 78, 85, 77, 80]), false));
    test('Too long', () => expect(isMagicString([147, 78, 85, 77, 80, 89, 90]), false));
    test('From valid text', () => expect(isMagicString('\x93NUMPY'.codeUnits), true));
  });

  group('NpVersion from bytes:', () {
    test('Empty iterable', () {
      expect(() => NpVersion.fromBytes([]), throwsA(const TypeMatcher<NpUnsupportedVersionException>()));
    });
    test('One entry', () {
      expect(() => NpVersion.fromBytes([1]), throwsA(const TypeMatcher<NpUnsupportedVersionException>()));
    });
    test('Supported version', () {
      final version = NpVersion.fromBytes([1, 0]);
      expect(version.major, 1);
      expect(version.minor, 0);
    });
    test('Unsupported major version', () {
      expect(() => NpVersion.fromBytes([4, 0]), throwsA(const TypeMatcher<NpUnsupportedVersionException>()));
    });
    test('Unsupported minor version', () {
      expect(() => NpVersion.fromBytes([1, 1]), throwsA(const TypeMatcher<NpUnsupportedVersionException>()));
    });
    test('Three entries', () {
      expect(() => NpVersion.fromBytes([1, 2, 3]), throwsA(const TypeMatcher<NpUnsupportedVersionException>()));
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
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpParseException>()));
      tmpFile.deleteSync();
    });
    test('Insufficient length', () {
      const filename = 'insufficient_length.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([1, 2, 3]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpParseException>()));
      tmpFile.deleteSync();
    });
    test('Invalid magic number', () {
      const filename = 'invalid_magic_number.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([1, 2, 3, 4, 5, 6]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpInvalidMagicNumberException>()));
      tmpFile.deleteSync();
    });
    test('Unsupported major version', () {
      const filename = 'unsupported_major_version.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 4, 0]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpUnsupportedVersionException>()));
      tmpFile.deleteSync();
    });
    test('Unsupported minor version', () {
      const filename = 'unsupported_minor_version.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 1, 1]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpUnsupportedVersionException>()));
      tmpFile.deleteSync();
    });
    test('Supported version 1', () async {
      const filename = 'supported_version_1.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 1, 0, 0x78, 0x56, 0x34, 0x12]);
      final npyFile = await loadNpy(filename);
      expect(npyFile.version.major, 1);
      expect(npyFile.version.minor, 0);
      expect(npyFile.headerLength, 0x5678);
      expect(npyFile.headerLength, 22136);
      tmpFile.deleteSync();
    });
    test('Supported version 2', () async {
      const filename = 'supported_version_2.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 2, 0, 0x78, 0x56, 0x34, 0x12]);
      final npyFile = await loadNpy(filename);
      expect(npyFile.version.major, 2);
      expect(npyFile.version.minor, 0);
      expect(npyFile.headerLength, 0x12345678);
      expect(npyFile.headerLength, 305419896);
      tmpFile.deleteSync();
    });
    test('Supported version 3', () async {
      const filename = 'supported_version_2.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([...magicString.codeUnits, 3, 0, 0x78, 0x56, 0x34, 0x12]);
      final npyFile = await loadNpy(filename);
      expect(npyFile.version.major, 3);
      expect(npyFile.version.minor, 0);
      expect(npyFile.headerLength, 0x12345678);
      expect(npyFile.headerLength, 305419896);
      tmpFile.deleteSync();
    });

    // test('np.array(0)', () async {
    //   await loadNpy('test/files/array_0.npy');
    //   // expect(loadNpy('test/array_0.npy'), throwsA(const TypeMatcher<int>()));
    // });
  });
}
