import 'package:npy/npy.dart';
import 'package:universal_io/io.dart';

void main() async {
  final ndarray = await NdArray.load('example/load/load_example.npy');
  stdout.writeln(ndarray.data);
}
