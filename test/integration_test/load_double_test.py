import numpy as np
import sys

loaded = np.load(sys.argv[1])

if not loaded.tolist() == [0.1, 0.2, -0.3]:
    sys.stderr.write(f"Error: Expected [0.1, 0.2, -0.3], got {loaded}\n")
    exit(1)

if not loaded.dtype == "float64":
    sys.stderr.write(f"Error: Expected dtype float64, got {loaded.dtype}\n")
    exit(1)

if not loaded.shape == (3,):
    sys.stderr.write(f"Error: Expected shape (3,), got {loaded.shape}\n")
    exit(1)
