CXX_OMP = g++
CXX_MPI = mpicxx
CXXFLAGS = -std=c++17 -O3 -march=native -fopenmp -Wall -Wextra -Werror -pedantic
TARGET = build/motor_hpc_farma
INSTALL_PATH = /usr/local/bin/motor_hpc_farma
SRC = src/motor_hpc_farma.cpp

.PHONY: all openmp mpi install clean

all: openmp

# Compilación 100% OpenMP (para el sprint actual sin requerir demonios MPI activos)
openmp:
	mkdir -p build
	$(CXX_OMP) $(CXXFLAGS) $(SRC) -o $(TARGET)

# Compilación Híbrida OpenMPI + OpenMP (escalable a N nodos)
mpi:
	mkdir -p build
	$(CXX_MPI) $(CXXFLAGS) -DUSE_MPI $(SRC) -o $(TARGET)

install:
	sudo cp $(TARGET) $(INSTALL_PATH)
	sudo chmod 755 $(INSTALL_PATH)

clean:
	rm -rf build/*
