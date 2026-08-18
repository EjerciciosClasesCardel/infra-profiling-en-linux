CXX = g++
FLAGS = -std=c++17 -O2 -g

lento: lento.cpp
	$(CXX) $(FLAGS) -o lento lento.cpp

rapido: rapido.cpp
	$(CXX) $(FLAGS) -o rapido rapido.cpp

comparar: lento rapido
	./lento  | tee lento.txt
	./rapido | tee rapido.txt

perfil: lento
	valgrind --tool=callgrind --callgrind-out-file=evidencia/callgrind.out ./lento
	callgrind_annotate evidencia/callgrind.out | tee evidencia/callgrind.txt

perfstat: lento
	perf stat -e cycles,instructions,cache-references,cache-misses ./lento 2> evidencia/perf.txt
	cat evidencia/perf.txt

limpiar:
	rm -f lento rapido lento.txt rapido.txt
