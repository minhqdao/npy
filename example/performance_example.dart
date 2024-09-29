import 'dart:io';
import 'dart:math';

import 'package:npy/npy.dart';

void main() async {
  const listLength = 2000000;
  const filename = 'performance_example.npy';
  final stopwatch = Stopwatch()..start();
  final list = List.generate(listLength, (_) => Random().nextDouble());
  stdout.writeln('List of doubles generated in ${stopwatch.elapsedMilliseconds} ms.');
  stopwatch.reset();
  await saveList(filename, list);
  stdout.writeln('List of doubles saved in ${stopwatch.elapsedMilliseconds} ms.');
  stopwatch.reset();
  await load(filename);
  stdout.writeln('List of doubles loaded in ${stopwatch.elapsedMilliseconds} ms.');
  File(filename).deleteSync();
}
