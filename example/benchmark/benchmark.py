import datetime
import numpy
import os

list_length = 2000000
filename = "python_benchmark.npy"
start_time = datetime.datetime.now()
list = numpy.random.uniform(0, 1, list_length)
end_time = datetime.datetime.now()
print("List created in", (end_time - start_time).total_seconds(), "seconds")
ndarray = numpy.array(list)
start_time = datetime.datetime.now()
numpy.save(filename, ndarray)
end_time = datetime.datetime.now()
print("List saved in", (end_time - start_time).total_seconds(), "seconds")
start_time = datetime.datetime.now()
loaded_array = numpy.load(filename)
end_time = datetime.datetime.now()
print("List loaded in", (end_time - start_time).total_seconds(), "seconds")
os.remove(filename)
