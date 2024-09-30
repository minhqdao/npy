import 'dart:io';

import 'package:npy/npy.dart';

void main() async {
  final ndarray = await load('example/load/load_example.npy');
  stdout.writeln(ndarray.data);
}
