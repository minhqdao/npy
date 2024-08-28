import 'package:npy/npy.dart';

void main() async {
  final ndarray = NdArray.fromList([1.0, 2.0, 3.0]);
  await save('example_save.npy', ndarray);
}
