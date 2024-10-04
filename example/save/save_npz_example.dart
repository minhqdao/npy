import 'package:npy/src/npy_ndarray.dart';
import 'package:npy/src/npy_npzfile.dart';

void main() async {
  final npzFile = NpzFile();
  final array1 = NdArray.fromList([1.0, 2.0, 3.0]);
  final array2 = NdArray.fromList([true, false, true]);
  npzFile
    ..add(array1)
    ..add(array2);
  await npzFile.save('example_save.npz');
}
