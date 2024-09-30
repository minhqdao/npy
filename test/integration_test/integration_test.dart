import 'dart:io';

import 'package:npy/npy.dart';
import 'package:test/test.dart';

void main() {
  const baseDir = 'test/integration_test/';

  group('Save:', () {
    test('1d float32', () async {
      const npyFilename = '${baseDir}save_float_test.npy';
      const pythonScript = '${baseDir}load_float_test.py';
      await saveList(npyFilename, [.111, 2.22, -33.3], dtype: NpyDType.float32());
      final result = await Process.run('python', [pythonScript, npyFilename]);
      File(npyFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
    test('2d bool, fortran order', () async {
      const npyFilename = '${baseDir}save_bool_test.npy';
      const pythonScript = '${baseDir}load_bool_test.py';
      await saveList(
        npyFilename,
        [
          [true, true, true],
          [false, false, false],
        ],
        fortranOrder: true,
      );
      final result = await Process.run('python', [pythonScript, npyFilename]);
      File(npyFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
    test('3d int16', () async {
      const npyFilename = '${baseDir}save_int_test.npy';
      const pythonScript = '${baseDir}load_int_test.py';
      await saveList(
        npyFilename,
        [
          [
            [1, 2, 3],
            [-4, 5, 6],
          ],
          [
            [-32768, 0, 9],
            [10, 11, 32767],
          ]
        ],
        dtype: NpyDType.int16(),
      );
      final result = await Process.run('python', [pythonScript, npyFilename]);
      File(npyFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
    test('2d uint32, big endian', () async {
      const npyFilename = '${baseDir}save_uint_test.npy';
      const pythonScript = '${baseDir}load_uint_test.py';
      await saveList(
        npyFilename,
        [
          [1, 2, 0],
          [4294967295, 5, 6],
        ],
        dtype: NpyDType.uint32(endian: NpyEndian.big),
      );
      final result = await Process.run('python', [pythonScript, npyFilename]);
      File(npyFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
  });

  group('Load:', () {
    test('2d float64, big endian', () async {
      const pythonScript = '${baseDir}save_float_test.py';
      const npyFilename = '${baseDir}load_float_test.npy';
      await Process.run('python', [pythonScript, npyFilename]);
      final ndarray = await load(npyFilename);
      File(npyFilename).deleteSync();
      expect(ndarray.data, [
        [-9.999, -1.1],
        [-0.12345, 0.12],
        [9.1, 1.999],
        [1.23, -1.2],
      ]);
      expect(ndarray.headerSection.header.fortranOrder, false);
      expect(ndarray.headerSection.header.shape, [4, 2]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.float);
      expect(ndarray.headerSection.header.dtype.endian, NpyEndian.big);
      expect(ndarray.headerSection.header.dtype.itemSize, 8);
    });
    test('3d bool', () async {
      const pythonScript = '${baseDir}save_bool_test.py';
      const npyFilename = '${baseDir}load_bool_test.npy';
      await Process.run('python', [pythonScript, npyFilename]);
      final ndarray = await load(npyFilename);
      File(npyFilename).deleteSync();
      expect(ndarray.data, [
        [
          [true, true, true],
          [false, false, false],
        ],
        [
          [false, false, false],
          [true, true, true],
        ]
      ]);
      expect(ndarray.headerSection.header.fortranOrder, false);
      expect(ndarray.headerSection.header.shape, [2, 2, 3]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.boolean);
      expect(ndarray.headerSection.header.dtype.endian, NpyEndian.none);
      expect(ndarray.headerSection.header.dtype.itemSize, 1);
    });
    test('2d int64, fortran order', () async {
      const pythonScript = '${baseDir}save_int_test.py';
      const npyFilename = '${baseDir}load_int_test.npy';
      await Process.run('python', [pythonScript, npyFilename]);
      final ndarray = await load(npyFilename);
      File(npyFilename).deleteSync();
      expect(ndarray.data, [
        [-9223372036854775808, -1],
        [0, 0],
        [1, 9223372036854775807],
      ]);
      expect(ndarray.headerSection.header.fortranOrder, true);
      expect(ndarray.headerSection.header.shape, [3, 2]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.int);
      expect(ndarray.headerSection.header.dtype.endian, NpyEndian.big);
      expect(ndarray.headerSection.header.dtype.itemSize, 8);
    });
    test('1d uint8', () async {
      const pythonScript = '${baseDir}save_uint_test.py';
      const npyFilename = '${baseDir}load_uint_test.npy';
      await Process.run('python', [pythonScript, npyFilename]);
      final ndarray = await load(npyFilename);
      File(npyFilename).deleteSync();
      expect(ndarray.data, [0, 1, 254, 255]);
      expect(ndarray.headerSection.header.fortranOrder, false);
      expect(ndarray.headerSection.header.shape, [4]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.uint);
      expect(ndarray.headerSection.header.dtype.endian, NpyEndian.none);
      expect(ndarray.headerSection.header.dtype.itemSize, 1);
    });
  });
}
