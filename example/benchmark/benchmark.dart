import 'dart:io';
import 'dart:math';

import 'package:npy/npy.dart';

void main() async {
  const listLength = 2000000;
  const filename = 'dart_benchmark.npy';
  final stopwatch = Stopwatch()..start();
  final list = List.generate(listLength, (_) => Random().nextDouble());
  stdout.writeln('List generated in ${stopwatch.elapsedMilliseconds} ms');
  stopwatch.reset();
  await save(filename, list);
  stdout.writeln('List saved in ${stopwatch.elapsedMilliseconds} ms');
  stopwatch.reset();
  await NdArray.load(filename);
  stdout.writeln('List loaded in ${stopwatch.elapsedMilliseconds} ms');
  File(filename).deleteSync();
}
