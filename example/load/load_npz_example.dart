import 'dart:io';

import 'package:npy/src/npy_npzfile.dart';

void main() async {
  final npzFile = await NpzFile.load('example/load/load_example.npz');
  stdout.writeln(npzFile.files['arr_0.npy']?.data);
  stdout.writeln(npzFile.files['arr_1.npy']?.data);
}
