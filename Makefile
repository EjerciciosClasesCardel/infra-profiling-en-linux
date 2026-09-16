CXX = g++
FLAGS = -std=c++17 -O2 -g

lento: lento.cpp
	$(CXX) $(FLAGS) -o lento lento.cpp

rapido: rapido.cpp
	$(CXX) $(FLAGS) -o rapido rapido.cpp

ocupado: ocupado.cpp
	$(CXX) $(FLAGS) -fopenmp -o ocupado ocupado.cpp

comparar: lento rapido
	./lento  | tee lento.txt
	./rapido | tee rapido.txt

# Lanza el programa de cuatro hilos y, mientras corre, lo mira con ps y top.
monitor: ocupado
	./ocupado & pid=$$!; sleep 2.5; \
	( echo "== ps -L: un renglon por hilo, %CPU promedio desde que arranco"; \
	  ps -L -o pid,tid,pcpu,psr,stat,comm -p $$pid; \
	  echo; echo "== top -H: %CPU del ultimo intervalo"; \
	  top -b -n 2 -d 0.5 -H -p $$pid | awk '/^top -/ {n++} n == 2' ) | tee evidencia/ps.txt; \
	wait $$pid

perfil: lento
	valgrind --tool=callgrind --callgrind-out-file=evidencia/callgrind.out ./lento
	callgrind_annotate evidencia/callgrind.out | tee evidencia/callgrind.txt

# Fallos de cache de las dos versiones, con el simulador de Valgrind.
cachegrind: lento rapido
	valgrind --tool=cachegrind --cache-sim=yes --cachegrind-out-file=evidencia/cachegrind_lento.out ./lento 2>&1 | tee evidencia/cachegrind_lento.txt
	valgrind --tool=cachegrind --cache-sim=yes --cachegrind-out-file=evidencia/cachegrind_rapido.out ./rapido 2>&1 | tee evidencia/cachegrind_rapido.txt

perfstat: lento
	perf stat -e cycles,instructions,cache-references,cache-misses ./lento 2> evidencia/perf.txt
	cat evidencia/perf.txt

limpiar:
	rm -f lento rapido ocupado lento.txt rapido.txt
