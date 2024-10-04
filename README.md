[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/minhqdao/npy/blob/main/LICENSE)

[![CI](https://github.com/minhqdao/npy/actions/workflows/ci.yml/badge.svg)](https://github.com/minhqdao/npy/actions/workflows/ci.yml)

Read and write NumPy binary files ( `.npy` and `.npz` ) in Dart.

## Usage

Load an `ndarray` from an `.npy` file:

```dart
final ndarray = await NdArray.load('example.npy');
```

Create an `ndarray` and save it as an `.npy` file:

```dart
final ndarray = NdArray.fromList([1.0, 2.0, 3.0]);
await ndarray.save('example_save.npy');
```

Conveniently save a `List` to an `.npy` file:

```dart
await save('example_save.npy', [[1, 2, 3], [4, 5, 6]]);
```

Read (compressed) `.npz` files:

```dart
final npzFile = await NpzFile.load('example.npz');
final arr_0 = npzFile.files['arr_0.npy'];
final arr_1 = npzFile.files['arr_1.npy'];
```

Write (compressed) `.npz` files:

```dart
final npzFile = NpzFile()
  ..add(NdArray.fromList([1.0, 2.0, 3.0]))
  ..add(NdArray.fromList([[true, false, true]]));
await npzFile.save('example_save.npz');
```

## Features

Load and save n-dimensional arrays of the following data types:

✅ float64, float32\
✅ int64, int32, int16, int8\
✅ uint64, uint32, uint16, uint8\
✅ bool

Supported memory representations:

✅ Little and Big Endian\
✅ C and Fortran order

Supported file formats:

✅ `.npy` \
✅ `.npz` (compressed and uncompressed)

## Tests

`dart test` will run integration tests, too, so make sure to have `python` and `numpy` installed and `python` available in your system's `PATH` .

## Further Information

Find more information on the `.npy` format [here](https://numpy.org/doc/stable/reference/generated/numpy.lib.format.html).

## Contribute

Feel free to [create an issue](https://github.com/minhqdao/npy/issues) in case you found a bug, have any questions or want to propose new features. Please [check open issues](https://github.com/minhqdao/npy/issues) before creating a new one. Make sure to satisfy formatter, analyzer and tests when [opening a pull request](https://github.com/minhqdao/npy/pulls).

## License

You can use, redistribute and/or modify the code under the terms of the [MIT License](https://github.com/minhqdao/npy/blob/main/LICENSE).
