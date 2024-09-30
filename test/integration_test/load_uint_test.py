import numpy as np
import sys

loaded = np.load(sys.argv[1])

if not loaded.tolist() == [[1, 2, 0], [4294967295, 5, 6]]:
    sys.stderr.write(f"Error: Expected [[1, 2, 0], [4294967295, 5, 6]], got {loaded}\n")
    exit(1)

if np.isfortran(loaded):
    sys.stderr.write(f"Error: Expected isfortran False, got {np.isfortran(loaded)}\n")
    exit(1)

if not loaded.shape == (2, 3):
    sys.stderr.write(f"Error: Expected shape (3,), got {loaded.shape}\n")
    exit(1)

if not loaded.dtype == ">u4":
    sys.stderr.write(f"Error: Expected dtype >u4, got {loaded.dtype}\n")
    exit(1)
