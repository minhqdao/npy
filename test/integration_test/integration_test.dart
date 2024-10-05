import 'dart:io';

import 'package:npy/npy.dart';
import 'package:test/test.dart';

void main() {
  const baseDir = 'test/integration_test/';

  Future<ProcessResult> runPython(String script, String filename) async {
    const executable = 'python';
    final executableResult = await Process.run('which', [executable]);
    if (executableResult.exitCode != 0) throw '$executable not found';
    final moduleResult = await Process.run(executable, ['-c', 'import numpy']);
    if (moduleResult.exitCode != 0) throw 'numpy not found';
    return await Process.run(executable, [script, filename]);
  }

  group('Save:', () {
    test('1d float32', () async {
      const npyFilename = '${baseDir}save_float_test.npy';
      const pythonScript = '${baseDir}load_float_test.py';
      await save(npyFilename, [.111, 2.22, -33.3], dtype: NpyDType.float32());
      final result = await runPython(pythonScript, npyFilename);
      File(npyFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
    test('2d bool, fortran order', () async {
      const npyFilename = '${baseDir}save_bool_test.npy';
      const pythonScript = '${baseDir}load_bool_test.py';
      await save(
        npyFilename,
        [
          [true, true, true],
          [false, false, false],
        ],
        fortranOrder: true,
      );
      final result = await runPython(pythonScript, npyFilename);
      File(npyFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
    test('3d int16', () async {
      const npyFilename = '${baseDir}save_int_test.npy';
      const pythonScript = '${baseDir}load_int_test.py';
      await save(
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
      final result = await runPython(pythonScript, npyFilename);
      File(npyFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
    test('2d uint32, big endian', () async {
      const npyFilename = '${baseDir}save_uint_test.npy';
      const pythonScript = '${baseDir}load_uint_test.py';
      await save(
        npyFilename,
        [
          [1, 2, 0],
          [4294967295, 5, 6],
        ],
        dtype: NpyDType.uint32(endian: NpyEndian.big),
      );
      final result = await runPython(pythonScript, npyFilename);
      File(npyFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
    test('Npz file with two arrays', () async {
      const npzFilename = '${baseDir}save_npz_test.npz';
      const pythonScript = '${baseDir}load_npz_test.py';
      final npzFile = NpzFile()
        ..add(
          NdArray.fromList(
            [
              [1.0, 2.0, 3.0],
              [4.0, 5.0, 6.0],
            ],
            endian: NpyEndian.big,
            fortranOrder: true,
          ),
        )
        ..add(NdArray.fromList([2, 4, -8], dtype: NpyDType.int16(endian: NpyEndian.little)));
      await npzFile.save(npzFilename);
      final result = await runPython(pythonScript, npzFilename);
      File(npzFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
    test('Npz file with two arrays, compressed', () async {
      const npzFilename = '${baseDir}save_npz_compressed_test.npz';
      const pythonScript = '${baseDir}load_npz_test.py';
      final npzFile = NpzFile()
        ..add(
          NdArray.fromList(
            [
              [1.0, 2.0, 3.0],
              [4.0, 5.0, 6.0],
            ],
            endian: NpyEndian.big,
            fortranOrder: true,
          ),
        )
        ..add(NdArray.fromList([2, 4, -8], dtype: NpyDType.int16(endian: NpyEndian.little)));
      await npzFile.save(npzFilename, isCompressed: true);
      final result = await runPython(pythonScript, npzFilename);
      File(npzFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
  });

  group('Load:', () {
    test('2d float64, big endian', () async {
      const pythonScript = '${baseDir}save_float_test.py';
      const npyFilename = '${baseDir}load_float_test.npy';
      await runPython(pythonScript, npyFilename);
      final ndarray = await NdArray.load(npyFilename);
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
      await runPython(pythonScript, npyFilename);
      final ndarray = await NdArray.load(npyFilename);
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
    test('2d int64, big endian, fortran order', () async {
      const pythonScript = '${baseDir}save_int_test.py';
      const npyFilename = '${baseDir}load_int_test.npy';
      await runPython(pythonScript, npyFilename);
      final ndarray = await NdArray.load(npyFilename);
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
      await runPython(pythonScript, npyFilename);
      final ndarray = await NdArray.load(npyFilename);
      File(npyFilename).deleteSync();
      expect(ndarray.data, [0, 1, 254, 255]);
      expect(ndarray.headerSection.header.fortranOrder, false);
      expect(ndarray.headerSection.header.shape, [4]);
      expect(ndarray.headerSection.header.dtype.type, NpyType.uint);
      expect(ndarray.headerSection.header.dtype.endian, NpyEndian.none);
      expect(ndarray.headerSection.header.dtype.itemSize, 1);
    });
    test('Npz file with two arrays', () async {
      const pythonScript = '${baseDir}save_npz_test.py';
      const npzFilename = '${baseDir}load_npz_test.npz';
      await runPython(pythonScript, npzFilename);
      final npzFile = await NpzFile.load(npzFilename);
      File(npzFilename).deleteSync();
      expect(npzFile.files.length, 2);
      final arr0 = npzFile.take('arr_0.npy');
      expect(arr0.data, [
        [-1.0, -2.0],
        [0.1, 0.2],
      ]);
      expect(arr0.headerSection.header.fortranOrder, false);
      expect(arr0.headerSection.header.shape, [2, 2]);
      expect(arr0.headerSection.header.dtype.type, NpyType.float);
      expect(arr0.headerSection.header.dtype.endian, NpyEndian.getNative());
      expect(arr0.headerSection.header.dtype.itemSize, 8);
      final arr1 = npzFile.take('arr_1.npy');
      expect(arr1.data, [
        [0],
        [1],
        [-128],
        [127],
      ]);
      expect(arr1.headerSection.header.fortranOrder, false);
      expect(arr1.headerSection.header.shape, [4, 1]);
      expect(arr1.headerSection.header.dtype.type, NpyType.int);
      expect(arr1.headerSection.header.dtype.endian, NpyEndian.none);
      expect(arr1.headerSection.header.dtype.itemSize, 1);
    });
    test('Npz file with two arrays, compressed', () async {
      const pythonScript = '${baseDir}save_npz_compressed_test.py';
      const npzFilename = '${baseDir}load_npz_compressed_test.npz';
      await runPython(pythonScript, npzFilename);
      final npzFile = await NpzFile.load(npzFilename);
      File(npzFilename).deleteSync();
      expect(npzFile.files.length, 2);
      final arr0 = npzFile.take('arr_0.npy');
      expect(arr0.data, [
        [-1.0, -2.0],
        [0.1, 0.2],
      ]);
      expect(arr0.headerSection.header.fortranOrder, false);
      expect(arr0.headerSection.header.shape, [2, 2]);
      expect(arr0.headerSection.header.dtype.type, NpyType.float);
      expect(arr0.headerSection.header.dtype.endian, NpyEndian.getNative());
      expect(arr0.headerSection.header.dtype.itemSize, 8);
      final arr1 = npzFile.take('arr_1.npy');
      expect(arr1.data, [
        [0],
        [1],
        [-128],
        [127],
      ]);
      expect(arr1.headerSection.header.fortranOrder, false);
      expect(arr1.headerSection.header.shape, [4, 1]);
      expect(arr1.headerSection.header.dtype.type, NpyType.int);
      expect(arr1.headerSection.header.dtype.endian, NpyEndian.none);
      expect(arr1.headerSection.header.dtype.itemSize, 1);
    });
  });

  group('Bytewise comparison:', () {
    test('2d float64, big endian', () async {
      const pythonScript = '${baseDir}save_float_test.py';
      const npyFilename = '${baseDir}compare_float_test.npy';
      await runPython(pythonScript, npyFilename);
      final pyBytes = await File(npyFilename).readAsBytes();
      File(npyFilename).deleteSync();
      final dartBytes = NdArray.fromList(
        [
          [-9.999, -1.1],
          [-0.12345, 0.12],
          [9.1, 1.999],
          [1.23, -1.2],
        ],
        endian: NpyEndian.big,
      ).asBytes;
      expect(pyBytes, dartBytes);
    });
    test('3d bool', () async {
      const pythonScript = '${baseDir}save_bool_test.py';
      const npyFilename = '${baseDir}compare_bool_test.npy';
      await runPython(pythonScript, npyFilename);
      final pyBytes = await File(npyFilename).readAsBytes();
      File(npyFilename).deleteSync();
      final dartBytes = NdArray.fromList(
        [
          [
            [true, true, true],
            [false, false, false],
          ],
          [
            [false, false, false],
            [true, true, true],
          ]
        ],
        endian: NpyEndian.none,
      ).asBytes;
      expect(pyBytes, dartBytes);
    });
    test('2d int64, fortran order', () async {
      const pythonScript = '${baseDir}save_int_test.py';
      const npyFilename = '${baseDir}compare_int_test.npy';
      await runPython(pythonScript, npyFilename);
      final pyBytes = await File(npyFilename).readAsBytes();
      File(npyFilename).deleteSync();
      final dartBytes = NdArray.fromList(
        [
          [-9223372036854775808, -1],
          [0, 0],
          [1, 9223372036854775807],
        ],
        endian: NpyEndian.big,
        fortranOrder: true,
      ).asBytes;
      expect(pyBytes, dartBytes);
    });
    test('1d uint8', () async {
      const pythonScript = '${baseDir}save_uint_test.py';
      const npyFilename = '${baseDir}compare_uint_test.npy';
      await runPython(pythonScript, npyFilename);
      final pyBytes = await File(npyFilename).readAsBytes();
      File(npyFilename).deleteSync();
      final dartBytes = NdArray.fromList([0, 1, 254, 255], dtype: const NpyDType.uint8()).asBytes;
      expect(pyBytes, dartBytes);
    });
  });
}
