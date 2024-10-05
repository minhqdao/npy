import 'package:npy/src/npy_npzfile.dart';
import 'package:universal_io/io.dart';

void main() async {
  final npzFile = await NpzFile.load('example/load/load_example.npz');
  final firstArray = npzFile.take('arr_0.npy');
  final secondArray = npzFile.take('arr_1.npy');
  stdout.writeln(firstArray.data);
  stdout.writeln(secondArray.data);
}
