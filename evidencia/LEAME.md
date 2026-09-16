Aquí van las salidas de las herramientas:

- `ps.txt`: `ps -L` y `top -H` sobre el programa de cuatro hilos, tomados
  mientras corría. Lo deja `make monitor`.
- `callgrind.txt`: salida de `callgrind_annotate` sobre el programa lento.
  Lo deja `make perfil`.
- `cachegrind_lento.txt` y `cachegrind_rapido.txt`: resumen de fallos de
  caché de cada versión. Los deja `make cachegrind`.
- `perf.txt`: salida de `perf stat` sobre el programa lento. Lo deja
  `make perfstat`.
