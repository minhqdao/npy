import 'dart:io';

import 'package:npy/npy.dart';
import 'package:test/test.dart';

void main() {
  group('Save:', () {
    test('1d list of doubles', () async {
      const npyFilename = 'test/integration_test/save_double_test.npy';
      const pythonScript = 'test/integration_test/load_double_test.py';
      await saveList(npyFilename, [.1, .2, -.3]);
      final result = await Process.run('python', [pythonScript, npyFilename]);
      File(npyFilename).deleteSync();
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
    // test('2d list of booleans, fortran order', () async {
    //   const npyFilename = 'test/integration_test/save_bool_test.npy';
    //   const pythonScript = 'test/integration_test/load_bool_test.py';
    //   await saveList(
    //     npyFilename,
    //     [
    //       [true, true, true],
    //       [false, false, false],
    //     ],
    //     fortranOrder: true,
    //   );
    //   final result = await Process.run('python', [pythonScript, npyFilename]);
    //   File(npyFilename).deleteSync();
    //   expect(result.exitCode, 0, reason: result.stderr.toString());
    // });
  });
  group('Load:', () {});
}
