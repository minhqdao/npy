import 'dart:io';

import 'package:npy/npy.dart';
import 'package:npy/src/np_exception.dart';
import 'package:npy/src/np_file.dart';
import 'package:test/test.dart';

void main() {
  group('Magic number:', () {
    test('Valid code units', () => expect(isMagicNumber([147, 78, 85, 77, 80, 89]), true));
    test('Invalid first byte', () => expect(isMagicNumber([146, 78, 85, 77, 80, 89]), false));
    test('Invalid last byte', () => expect(isMagicNumber([147, 78, 85, 77, 80, 87]), false));
    test('Too short', () => expect(isMagicNumber([147, 78, 85, 77, 80]), false));
    test('Too long', () => expect(isMagicNumber([147, 78, 85, 77, 80, 89, 90]), false));
    test('From valid text', () => expect(isMagicNumber('\x93NUMPY'.codeUnits), true));
  });

  group('NpVersion from bytes:', () {
    test('Empty iterable', () {
      expect(() => NpVersion.fromBytes([]), throwsA(const TypeMatcher<NpInvalidVersionException>()));
    });
    test('One entry', () {
      expect(() => NpVersion.fromBytes([1]), throwsA(const TypeMatcher<NpInvalidVersionException>()));
    });
    test('Supported version', () {
      final version = NpVersion.fromBytes([1, 0]);
      expect(version.major, 1);
      expect(version.minor, 0);
    });
    test('Unsupported major version', () {
      expect(() => NpVersion.fromBytes([4, 0]), throwsA(const TypeMatcher<NpInvalidVersionException>()));
    });
    test('Unsupported minor version', () {
      expect(() => NpVersion.fromBytes([1, 1]), throwsA(const TypeMatcher<NpInvalidVersionException>()));
    });
    test('Three entries', () {
      expect(() => NpVersion.fromBytes([1, 2, 3]), throwsA(const TypeMatcher<NpInvalidVersionException>()));
    });
  });

  group('Load npy:', () {
    test('Non-existent file', () {
      expect(loadNpy('not_existent.npy'), throwsA(const TypeMatcher<NpFileNotExistsException>()));
    });
    test('Pointing at current directory', () {
      expect(loadNpy('.'), throwsA(const TypeMatcher<NpFileOpenException>()));
    });
    test('Empty file', () async {
      const filename = 'empty_file.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpInsufficientLengthException>()));
      tmpFile.deleteSync();
    });
    test('Insufficient length', () async {
      const filename = 'insufficient_length.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([1, 2, 3]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpInsufficientLengthException>()));
      tmpFile.deleteSync();
    });
    test('Invalid magic number', () async {
      const filename = 'invalid_magic_number.tmp';
      final tmpFile = File(filename)..writeAsBytesSync([1, 2, 3, 4, 5, 6]);
      expect(loadNpy(filename), throwsA(const TypeMatcher<NpInvalidMagicNumberException>()));
      tmpFile.deleteSync();
    });

    // test('np.array(0)', () async {
    //   await loadNpy('test/files/array_0.npy');
    //   // expect(loadNpy('test/array_0.npy'), throwsA(const TypeMatcher<int>()));
    // });
  });
}
