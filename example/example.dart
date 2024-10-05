import 'package:npy/npy.dart';
import 'package:universal_io/io.dart';

void main() async {
  const npyFilename = 'example.npy';
  final ndarray = NdArray.fromList([1.001, -2.002, 3.003]);
  await ndarray.save(npyFilename);

  final loadedArray = await NdArray.load(npyFilename);
  File(npyFilename).deleteSync();
  stdout.writeln(loadedArray.data);

  const npzFilename = 'example.npz';
  final npzFile = NpzFile();
  npzFile.add(loadedArray);
  await npzFile.save(npzFilename);

  final loadedNpzFile = await NpzFile.load(npzFilename);
  File(npzFilename).deleteSync();
  stdout.writeln(loadedNpzFile.take('arr_0.npy').data);
}
