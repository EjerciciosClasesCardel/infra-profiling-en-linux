# Documentación de apoyo: perfilado en Linux

Aquí están las herramientas que cada paso del README necesita: qué hace cada
una, con qué opciones se invoca y cómo se lee lo que devuelve. Hay una sección
por paso, en el mismo orden y con el mismo nombre. Cada ejemplo es un programa
completo que se copia y corre tal cual, con su salida real recortada; ninguno
resuelve lo que pide el README, todos resuelven un problema vecino. Los enlaces
a la documentación van al final de cada sección.

## Paso 0: mirar un programa desde afuera

### Lo que se usa

- `ps -L -o pid,tid,psr,pcpu,comm -p <pid>`. Con `-L` cada hilo del proceso
  ocupa un renglón. `-o` escoge las columnas: `pid` es el proceso, `tid` el
  identificador del hilo (el hilo principal tiene el mismo número que el
  proceso), `psr` el procesador donde el hilo corrió por última vez, `pcpu` el
  tiempo de CPU consumido dividido por el tiempo que el hilo lleva vivo,
  expresado en porcentaje, y `comm` el nombre. `-p` restringe la lista a un
  proceso. La columna `%CPU` de `ps` es un promedio desde que el hilo arrancó,
  no una lectura del instante.
- `top -H -p <pid>`. La tecla `H` alterna entre ver el proceso completo y ver
  un renglón por hilo; `-H` arranca ya en ese modo. `%CPU` aquí es la fracción
  del último intervalo de refresco (`-d` segundos) en que el hilo estuvo en
  CPU. En modo batch, `top -b -n 2 -d 0.5`, imprime dos cuadros y termina; el
  primero se calcula desde que el proceso nació y el segundo sí mide el
  intervalo, por eso el Makefile se queda con el segundo.
- `htop`. Interactivo: `H` muestra u oculta los hilos de usuario; `F2` abre
  la configuración, y en `Columns` se agrega `PROCESSOR`, que es la misma
  información que `PSR` en `ps`. `F4` filtra por nombre y `q` sale.
- En `ocupado.cpp`: `omp_set_num_threads(int n)` fija cuántos hilos abrirá la
  siguiente región paralela; `omp_get_thread_num()` devuelve el número del hilo
  que la llama, de `0` a `n - 1`; `#pragma omp parallel reduction(+ : x)` abre
  la región y suma al final la copia privada de `x` de cada hilo. Se compila
  con `-fopenmp`.
- En el ejemplo de abajo, la alternativa sin OpenMP: `std::thread t(f)` lanza
  un hilo que ejecuta `f`, `t.join()` espera a que termine, y
  `pthread_setname_np(pthread_self(), "nombre")` le pone un nombre de hasta
  15 caracteres, que es lo que `ps` y `top` muestran en `COMMAND`.
- `std::chrono::steady_clock::now()` da un instante de un reloj que no se
  ajusta hacia atrás; sirve para esperas y cronómetros.

### Ejemplo

Tres hilos con nombre y ocupación distinta: uno trabaja los cinco segundos
completos, otro alterna 100 ms de trabajo y 100 ms de pausa, y el tercero solo
duerme. Guardado como `tres.cpp`:

```cpp
// Tres hilos con ocupación distinta durante cinco segundos: uno trabaja
// sin parar, otro alterna trabajo y descanso por mitades y el tercero solo
// duerme. Cada hilo lleva un nombre para reconocerlo en ps y top.
#include <chrono>
#include <cstdio>
#include <pthread.h>
#include <thread>

using namespace std::chrono;

// Quema CPU hasta que pase el tiempo indicado.
void quemar(milliseconds cuanto, double &acum) {
  auto fin = steady_clock::now() + cuanto;
  while (steady_clock::now() < fin)
    for (int k = 0; k < 1000; k++) acum += k * 0.5;
}

int main() {
  double x = 0, y = 0;
  std::thread lleno([&] {
    pthread_setname_np(pthread_self(), "lleno");
    quemar(seconds(5), x);
  });
  std::thread medio([&] {
    pthread_setname_np(pthread_self(), "medio");
    for (int i = 0; i < 25; i++) {           // 100 ms de trabajo, 100 ms de pausa
      quemar(milliseconds(100), y);
      std::this_thread::sleep_for(milliseconds(100));
    }
  });
  std::thread dormido([] {
    pthread_setname_np(pthread_self(), "dormido");
    std::this_thread::sleep_for(seconds(5));
  });
  lleno.join(); medio.join(); dormido.join();
  printf("listo %.0f %.0f\n", x, y);
  return 0;
}
```

Se compila, se lanza al fondo y a los dos segundos y medio se le toman las
dos fotos:

```bash
g++ -std=c++17 -O2 -g -pthread -o tres tres.cpp
./tres & pid=$!
sleep 2.5
ps -L -o pid,tid,psr,pcpu,stat,comm -p $pid
top -b -n 2 -d 0.5 -H -p $pid | awk '/^top -/ {n++} n == 2'
wait $pid
```

Salida en esta máquina:

```
    PID     TID PSR %CPU STAT COMMAND
  98646   98646   8  0.0 SNl  tres
  98646   98648   0 99.2 RNl  lleno
  98646   98649   7 51.6 SNl  medio
  98646   98650   1  0.0 SNl  dormido

Threads: 4 total, 2 running, 2 sleep, 0 d-sleep, 0 stopped, 0 zombie

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
  98648 cardel    25   5   32008   4180   3940 R  99,8   0,0   0:03.19 lleno
  98649 cardel    25   5   32008   4180   3940 R  41,9   0,0   0:01.60 medio
  98646 cardel    25   5   32008   4180   3940 S   0,0   0,0   0:00.00 tres
  98650 cardel    25   5   32008   4180   3940 S   0,0   0,0   0:00.00 dormido
```

Cuatro renglones: el hilo principal, que se llama como el programa y está
esperando en `join`, y los tres que se lanzaron. `PSR` dice en qué procesador
estaba cada uno en ese instante (0, 7 y 1). Para `medio`, `ps` reporta 51,6 y
`top` 41,9: uno promedia desde que el hilo nació y el otro mira solo el último
medio segundo, y en medio segundo el hilo pudo estar en la mitad de trabajo o
en la de pausa. La columna `S` (`R` corriendo, `S` durmiendo) es la misma
letra que abre `STAT` en `ps`.

Para verlo en vivo, `./tres &` en una terminal y `htop -p $!` en otra: con
`H` aparecen los cuatro renglones y, si se agregó `PROCESSOR` con `F2`, se ve
al planificador moverlos de núcleo.

### Lo que suele fallar

- `ps -L` muestra un solo renglón. El programa ya terminó cuando se tomó la
  foto, o el `pid` es de otro proceso. Con `./programa & pid=$!` el número
  queda en `$!` justo después del `&`; si entre medio se lanzó otra cosa al
  fondo, `$!` cambió.
- La verificación cuenta los renglones cuya última columna dice `ocupado`.
  Si se cambia el nombre de los hilos con `pthread_setname_np`, o se modifica
  `ocupado.cpp`, el conteo da menos de cuatro y el paso queda en rojo.
- Falta `-fopenmp` al compilar `ocupado.cpp`: `undefined reference to
  omp_set_num_threads`. Con `make ocupado` la bandera ya está puesta; a mano
  hay que escribirla.
- `top -b -n 1` da porcentajes que se parecen a los de `ps` y no a los del
  intervalo: el primer cuadro de `top` no tiene con qué comparar. Se piden dos
  cuadros y se usa el segundo, que es lo que hace el `awk` del Makefile.
- `%CPU` mayor que 100 en el renglón del proceso cuando se corre `ps` sin
  `-L`: es la suma de los hilos. Con `-L` cada hilo va por su lado y ninguno
  pasa de 100.

### Enlaces

- [ps(1)](https://man7.org/linux/man-pages/man1/ps.1.html): la lista completa
  de columnas de `-o`, incluidas `psr`, `pcpu` y `tid`, y cómo se calcula
  `%CPU`.
- [top(1)](https://man7.org/linux/man-pages/man1/top.1.html): las teclas del
  modo interactivo, entre ellas `H`, y las opciones `-b`, `-n`, `-d` y `-H`.
- [htop(1)](https://man7.org/linux/man-pages/man1/htop.1.html): teclas y
  columnas disponibles, con `PROCESSOR` entre ellas.
- [pthread_setname_np(3)](https://man7.org/linux/man-pages/man3/pthread_setname_np.3.html):
  cómo ponerle nombre a un hilo y el límite de 15 caracteres.
- [std::thread en cppreference](https://en.cppreference.com/w/cpp/thread/thread):
  constructor, `join` y `detach`.
- [Especificaciones de OpenMP](https://www.openmp.org/specifications/): la
  referencia de `omp_get_thread_num`, `omp_set_num_threads` y la cláusula
  `reduction`.

## Paso 1: medir

`lento.cpp` es el programa que se mide. Antes de tocarlo, tres herramientas
distintas responden tres preguntas distintas: Callgrind dice qué línea
ejecuta más instrucciones, Cachegrind simula la caché y cuenta cuántos
accesos fallan, y `perf` lee los contadores del procesador mientras el
programa corre a velocidad real.

### Lo que se usa

- `valgrind --tool=callgrind --callgrind-out-file=<archivo> ./programa`.
  Ejecuta el programa instrucción por instrucción y anota cuántas ejecutó cada
  función y cada línea. Corre entre 20 y 100 veces más lento que el programa
  solo, así que el tiempo que el programa imprime bajo Valgrind no es una
  medición de nada.
- `callgrind_annotate <archivo>`. Lee ese archivo y lo presenta ordenado. La
  columna `Ir` (*instructions read*) es el conteo de instrucciones de máquina
  ejecutadas: primero el total, después por función y, si el programa se
  compiló con `-g` y el fuente está a mano, línea por línea. Un porcentaje
  alto en una línea es el lugar donde se va el trabajo.
- `--dump-instr=yes`. Le pide a Callgrind que guarde los conteos por
  instrucción de máquina en vez de por línea de fuente. `callgrind_annotate`
  no los muestra; los usa el visor gráfico KCachegrind para la vista de
  ensamblador. En terminal basta la anotación por línea.
- `valgrind --tool=cachegrind --cache-sim=yes --cachegrind-out-file=<archivo> ./programa`.
  Simula una caché de primer nivel (`D1` para datos, `I1` para instrucciones)
  y una de último nivel (`LL`), con los tamaños que lee del procesador. Sin
  `--cache-sim=yes` solo cuenta instrucciones. El resumen sale por la salida
  de error, de ahí el `2>&1` del Makefile. Las líneas que se leen:
  `D refs`, cuántos accesos a datos hubo; `D1 misses` y `D1 miss rate`,
  cuántos de ellos no estaban en la caché de primer nivel y qué fracción es;
  `LLd misses` y `LLd miss rate`, cuántos tampoco estaban en la de último
  nivel y hubo que ir a memoria.
- `cg_annotate <archivo>`. Reparte esos conteos por función y por línea, con
  una columna por evento: `Dr` lecturas de datos, `D1mr` lecturas que fallaron
  en D1, `DLmr` las que fallaron en LL. `--show=Ir,Dr,D1mr,DLmr` deja solo
  esas columnas.
- `perf stat -e cycles,instructions,cache-references,cache-misses,L1-dcache-load-misses ./programa`.
  Corre el programa a velocidad normal y lee los contadores de hardware al
  final: ciclos, instrucciones, accesos que llegaron a la caché de último
  nivel, los que fallaron allí, y las lecturas que fallaron en L1 de datos.
  Con `-r 5` repite cinco veces y reporta la variación. Escribe el informe en
  la salida de error.
- `perf record ./programa` y `perf report --stdio`. La primera interrumpe el
  programa varios miles de veces por segundo y anota en qué función estaba;
  la segunda muestra el porcentaje de muestras que cayó en cada una. Es la
  forma de ver dónde se va el tiempo de verdad, no las instrucciones.
- `kernel.perf_event_paranoid`. Un ajuste del kernel que decide qué puede
  medir un usuario sin privilegios. Se consulta con
  `cat /proc/sys/kernel/perf_event_paranoid`: con 2 se miden los eventos del
  propio programa en espacio de usuario (aparecen con el sufijo `:u`); con 3
  o más `perf` responde `Access to performance monitoring and observability
  operations is not permitted`. Se baja con
  `sudo sysctl -w kernel.perf_event_paranoid=1`, y para que sobreviva al
  reinicio se escribe esa misma línea en `/etc/sysctl.d/99-perf.conf`.
- `/usr/bin/time -v ./programa`. Es el `time` de GNU, distinto del `time`
  interno de la shell; con `-v` reporta tiempo de usuario y de sistema, el
  porcentaje de CPU que el proceso obtuvo, el pico de memoria residente y los
  fallos de página.
- `lscpu` describe el procesador: núcleos, hilos por núcleo, tamaños de L1,
  L2 y L3; `lscpu -C` da una tabla con cada nivel, sus vías y el tamaño de
  línea. `getconf LEVEL1_DCACHE_LINESIZE` imprime solo el tamaño de la línea
  de la caché de datos de primer nivel, en bytes, y
  `getconf LEVEL1_DCACHE_SIZE` su capacidad.

### Ejemplo

Callgrind. Dos funciones de costo muy distinto en `dos.cpp`: una cuenta primos
por división de prueba y la otra suma los enteros de un rango.

```cpp
// Dos funciones de costo muy distinto: una cuenta primos por división de
// prueba y la otra suma los enteros de un rango. Callgrind dice cuál se
// lleva las instrucciones.
#include <cstdio>

// Cuenta los primos menores que n probando divisores hasta la raíz.
long contar_primos(long n) {
  long cuantos = 0;
  for (long x = 2; x < n; x++) {
    bool primo = true;
    for (long d = 2; d * d <= x; d++)
      if (x % d == 0) { primo = false; break; }
    if (primo) cuantos++;
  }
  return cuantos;
}

// Suma los enteros de 1 a n.
long sumar_hasta(long n) {
  long s = 0;
  for (long x = 1; x <= n; x++) s += x;
  return s;
}

int main() {
  printf("primos %ld suma %ld\n", contar_primos(200000), sumar_hasta(200000));
  return 0;
}
```

```bash
g++ -std=c++17 -O2 -g -o dos dos.cpp
valgrind --tool=callgrind --callgrind-out-file=callgrind.out ./dos
callgrind_annotate callgrind.out
```

```
primos 17984 suma 20000100000
==99739== I   refs:      74,790,794

Ir                   file:function
--------------------------------------------------------------------------------
71,982,540 (96.25%)  dos.cpp:main [.../dos]
   748,240 ( 1.00%)  .../dl-new-hash.h:_dl_lookup_symbol_x

-- Auto-annotated source: dos.cpp
Ir
         1 ( 0.00%)    long cuantos = 0;
   599,995 ( 0.80%)    for (long x = 2; x < n; x++) {
35,527,236 (47.50%)      for (long d = 2; d * d <= x; d++)
35,837,310 (47.92%)        if (x % d == 0) { primo = false; break; }
    17,984 ( 0.02%)      if (primo) cuantos++;
         .           long sumar_hasta(long n) {
         .             for (long x = 1; x <= n; x++) s += x;
```

Con `-O2` las dos funciones quedaron dentro de `main`, así que la tabla por
función solo dice `main`; la anotación por línea es la que responde: el 95 %
de las 74.790.794 instrucciones está en las dos líneas del bucle interno de
`contar_primos`, y `sumar_hasta` no tiene ni una, porque el compilador la
reemplazó por la fórmula cerrada. Si se necesita la tabla por función se
compila con `-fno-inline`:

```bash
g++ -std=c++17 -O2 -g -fno-inline -o dos dos.cpp
valgrind --tool=callgrind --callgrind-out-file=callgrind.out ./dos
callgrind_annotate callgrind.out | head -30
```

```
71,982,532 (95.73%)  dos.cpp:contar_primos(long) [.../dos]
   400,009 ( 0.53%)  dos.cpp:sumar_hasta(long) [.../dos]
```

Cachegrind y `perf`. El mismo arreglo sumado dos veces en `acceso.cpp`: en
orden, y siguiendo un orden que salta por todo el arreglo. Las dos sumas leen
los mismos 4.194.304 números y dan el mismo resultado.

```cpp
// El mismo arreglo sumado dos veces: en orden y siguiendo un orden que salta
// por todo el arreglo. Las dos sumas leen los mismos números y dan el mismo
// resultado; lo que cambia es cuántas veces la caché tiene lo que se le pide.
#include <chrono>
#include <cstdio>
#include <vector>

using namespace std;
using namespace std::chrono;

const long N = 1 << 22;  // 4.194.304 doubles, 32 MB

double sumar_seguido(const vector<double> &a) {
  double s = 0;
  for (long i = 0; i < N; i++) s += a[i];
  return s;
}

double sumar_saltando(const vector<double> &a, const vector<long> &orden) {
  double s = 0;
  for (long i = 0; i < N; i++) s += a[orden[i]];
  return s;
}

int main() {
  vector<double> a(N);
  for (long i = 0; i < N; i++) a[i] = (i % 9) * 0.5;

  // Un salto impar sobre un tamaño potencia de dos pasa por todas las
  // posiciones exactamente una vez.
  vector<long> orden(N);
  for (long i = 0; i < N; i++) orden[i] = (i * 1000003) % N;

  auto t0 = high_resolution_clock::now();
  double s1 = sumar_seguido(a);
  auto t1 = high_resolution_clock::now();
  double s2 = sumar_saltando(a, orden);
  auto t2 = high_resolution_clock::now();
  printf("seguido %ld ms suma %.1f\n", duration_cast<milliseconds>(t1 - t0).count(), s1);
  printf("saltando %ld ms suma %.1f\n", duration_cast<milliseconds>(t2 - t1).count(), s2);
  return 0;
}
```

```bash
g++ -std=c++17 -O2 -g -o acceso acceso.cpp
./acceso
valgrind --tool=cachegrind --cache-sim=yes --cachegrind-out-file=cachegrind.out ./acceso
cg_annotate --show=Ir,Dr,D1mr,DLmr cachegrind.out
```

```
seguido 3 ms suma 8388604.5
saltando 10 ms suma 8388604.5

==109839== D refs:         24,042,874  (13,305,046 rd   + 10,737,828 wr)
==109839== D1  misses:      7,367,368  ( 5,267,852 rd   +  2,099,516 wr)
==109839== LLd misses:      2,453,163  ( 1,403,246 rd   +  1,049,917 wr)
==109839== D1  miss rate:        30.6% (      39.6%     +       19.6%  )
==109839== LLd miss rate:        10.2% (      10.5%     +        9.8%  )

D1 cache:         32768 B, 64 B, 8-way associative
LL cache:         33554432 B, 64 B, direct-mapped

Ir________________ Dr_______________ D1mr_____________ DLmr___________
10,485,764  (8.1%) 4,194,304 (31.5%)   524,289 (10.0%) 524,289 (37.4%)    for (long i = 0; i < N; i++) s += a[i];
16,777,219 (12.9%) 4,194,304 (31.5%) 4,194,304 (79.6%) 344,875 (24.6%)    for (long i = 0; i < N; i++) s += a[orden[i]];
```

La misma cantidad de lecturas en cada línea, 4.194.304, pero la suma en orden
falló 524.289 veces en D1, una de cada ocho, y la suma saltando falló las
4.194.304, todas. Una línea de caché de 64 bytes trae ocho `double` juntos.
Si se recorre en orden, el primer acceso paga la línea y los siete
siguientes ya la tienen; si se salta, cada acceso cae en una línea que nadie
trajo.

Los contadores de hardware sobre el mismo programa, con
`kernel.perf_event_paranoid` en 2:

```bash
perf stat -e cycles,instructions,cache-references,cache-misses,L1-dcache-load-misses ./acceso
```

```
        91.638.276      cycles:u
       130.088.809      instructions:u
         9.630.910      cache-references:u
         4.243.652      cache-misses:u
         6.304.317      L1-dcache-load-misses:u

       0,030252617 seconds time elapsed
```

`L1-dcache-load-misses` cuenta 6.304.317, cerca de los 5.267.852 fallos de
lectura que simuló Cachegrind. No coinciden exactamente: el contador mide un
chip que trae líneas por adelantado y el simulador una caché ideal de 32 KB
con líneas de 64 bytes. El orden de magnitud es el mismo.

Dónde cae el tiempo, con muestreo. Sobre el binario compilado con
`-fno-inline` para que las funciones aparezcan por separado:

```bash
g++ -std=c++17 -O2 -g -fno-inline -o acceso_fn acceso.cpp
perf record -o perf_fn.data ./acceso_fn
perf report -i perf_fn.data --stdio --sort symbol
```

```
[ perf record: Captured and wrote 0,011 MB perf_fn.data (239 samples) ]

    54.61%  [.] sumar_saltando(std::vector<double, ...> const&, std::vector<long, ...> const&)
    23.46%  [.] main
    10.43%  [.] sumar_seguido(std::vector<double, ...> const&)
```

El conteo de instrucciones de Cachegrind daba 16 a 10 entre
`sumar_saltando` y `sumar_seguido`; el muestreo de tiempo da 54 a 10. La
diferencia entre las dos proporciones es la memoria.

El resumen de recursos:

```bash
/usr/bin/time -v ./acceso
```

```
	User time (seconds): 0.02
	System time (seconds): 0.00
	Percent of CPU this job got: 93%
	Elapsed (wall clock) time (h:mm:ss or m:ss): 0:00.02
	Maximum resident set size (kbytes): 69572
```

Los 69.572 kB de memoria residente son los dos arreglos de 32 MB y un poco
más. Y la máquina donde se midió todo esto:

```bash
getconf LEVEL1_DCACHE_LINESIZE
getconf LEVEL1_DCACHE_SIZE
lscpu -C
```

```
64
32768
NAME ONE-SIZE ALL-SIZE WAYS TYPE        LEVEL  SETS PHY-LINE COHERENCY-SIZE
L1d       32K     192K    8 Data            1    64        1             64
L1i       32K     192K    8 Instruction     1    64        1             64
L2       512K       3M    8 Unified         2  1024        1             64
L3        16M      32M   16 Unified         3 16384        1             64
```

Líneas de 64 bytes, 32 KB de datos por núcleo en L1: los mismos números que
Cachegrind puso en su encabezado.

### Lo que suele fallar

- `callgrind_annotate` muestra `???` en vez del nombre del archivo y no
  anota líneas: el binario se compiló sin `-g`. El Makefile ya lo lleva en
  `FLAGS`; si se compila a mano hay que ponerlo.
- El resumen de Cachegrind no trae las líneas `D1` ni `LLd`, y el flujo de
  Actions responde `cachegrind no dejo la tasa de fallos de D1`: faltó
  `--cache-sim=yes`. Desde Valgrind 3.22 la simulación viene apagada.
- `evidencia/perf.txt` queda vacío: `perf stat` escribe el informe por la
  salida de error. Se captura con `2> evidencia/perf.txt`, como hace el
  Makefile, no con `>`.
- `perf stat` responde `Access to performance monitoring and observability
  operations is not permitted`: `kernel.perf_event_paranoid` está en 3 o 4.
  Se baja con `sysctl` como se indicó arriba. Si en lugar de números aparece
  `<not supported>` en `cycles` o `cache-misses`, el procesador no expone
  contadores a ese entorno; pasa en máquinas virtuales y en WSL2.
- El tiempo que imprime el programa corriendo bajo Valgrind se copia a la
  tabla de resultados. Ese número es de la simulación, entre 20 y 100 veces
  más lento; los tiempos van con `./lento` y `./rapido` a secas.
- `make cachegrind` corre sobre `rapido` antes de escribirlo: el archivo
  `cachegrind_rapido.txt` queda con los fallos de un programa que no
  multiplica nada. Se repite la regla al terminar el paso siguiente.

### Enlaces

- [Manual de Callgrind](https://valgrind.org/docs/manual/cl-manual.html):
  opciones de `valgrind --tool=callgrind`, `--dump-instr`, y cómo leer
  `callgrind_annotate`.
- [Manual de Cachegrind](https://valgrind.org/docs/manual/cg-manual.html):
  `--cache-sim`, el significado de cada evento (`Dr`, `D1mr`, `DLmr`) y
  `cg_annotate`.
- [Opciones comunes de Valgrind](https://valgrind.org/docs/manual/manual-core.html):
  las banderas que valen para cualquier herramienta.
- [Tutorial de perf](https://perf.wiki.kernel.org/index.php/Tutorial): `perf
  stat`, `perf record`, `perf report` y la lista de eventos, escrito por
  los autores.
- [perf-stat(1)](https://man7.org/linux/man-pages/man1/perf-stat.1.html):
  la opción `-e`, `-r` para repetir, y la sintaxis de los eventos.
- [Seguridad de perf en la documentación del kernel](https://www.kernel.org/doc/html/latest/admin-guide/perf-security.html):
  qué permite cada valor de `perf_event_paranoid`.
- [GNU time](https://www.gnu.org/software/time/): el significado de cada
  campo de `-v`.
- [lscpu(1)](https://man7.org/linux/man-pages/man1/lscpu.1.html) y
  [sysconf(3)](https://man7.org/linux/man-pages/man3/sysconf.3.html): la
  descripción del procesador y las variables `LEVEL1_DCACHE_*` que `getconf`
  consulta.

## Paso 2: escribir la versión rápida

### Lo que se usa

- `std::vector<double> m(N * N)`. Un solo bloque contiguo de `N * N` valores,
  inicializados en cero. `m[k]` es la posición `k`; con `m(N * N, 0.0)` se
  dice el valor inicial explícitamente.
- `m[i * N + j]`. Es la forma de guardar una matriz de `N` filas y `N`
  columnas en un arreglo de una dimensión, y es lo que quiere decir que la
  matriz está *guardada por filas*: primero van los `N` elementos de la fila
  0, después los `N` de la fila 1, y así. Los vecinos de `(i, j)` en memoria
  son `(i, j - 1)` y `(i, j + 1)`; el elemento de la fila siguiente,
  `(i + 1, j)`, está `N` posiciones más allá, `8 * N` bytes con `double`.
  Para `N = 4` queda así, con la posición en el arreglo arriba y el elemento
  de la matriz abajo:

  ```
  posición:   0     1     2     3     4     5     6     7     8     9    10    11    12    13    14    15
  elemento: (0,0) (0,1) (0,2) (0,3) (1,0) (1,1) (1,2) (1,3) (2,0) (2,1) (2,2) (2,3) (3,0) (3,1) (3,2) (3,3)
  ```

  La fila 1 son las posiciones 4, 5, 6 y 7, seguidas. La columna 1 son las
  posiciones 1, 5, 9 y 13, a saltos de `N`. Una línea de caché de 64 bytes
  contiene ocho `double` consecutivos: recorrer una fila usa cada línea ocho
  veces; bajar por una columna usa cada línea una vez y, si `8 * N` es más
  grande que lo que la caché retiene, cuando se vuelve a esa línea ya no
  está.
- `high_resolution_clock::now()` y
  `duration_cast<milliseconds>(t1 - t0).count()`: el instante antes y el
  instante después, y la diferencia convertida a un entero de milisegundos.
- `printf("tiempo %ld ms checksum %.3f\n", ...)`: `%ld` para el `long` que
  devuelve `count()` y `%.3f` para el `double` con tres decimales. La
  verificación separa la línea por espacios y toma el segundo campo como
  tiempo y el quinto como checksum, así que el texto se conserva letra por
  letra.

### Ejemplo

Un solo arreglo de 4.096 por 4.096 `double` sumado completo de dos maneras,
en `recorrido.cpp`. El argumento escoge cuál: `filas` recorre cada fila de
principio a fin; `columnas` baja por cada columna. La suma es la misma.

```cpp
// Un arreglo de N*N doubles, leído como una matriz guardada por filas:
// el elemento (i, j) está en la posición i*N + j. El programa lo suma
// completo de dos maneras y el argumento dice cuál: "filas" recorre cada
// fila de principio a fin; "columnas" baja por cada columna.
#include <chrono>
#include <cstdio>
#include <cstring>
#include <vector>

using namespace std;
using namespace std::chrono;

const int N = 4096;  // 4096 * 4096 doubles = 128 MB

int main(int argc, char **argv) {
  bool por_filas = argc < 2 || strcmp(argv[1], "columnas") != 0;
  vector<double> m(N * N);
  for (int i = 0; i < N * N; i++) m[i] = (i % 11) * 0.25;

  auto t0 = high_resolution_clock::now();
  double suma = 0;
  if (por_filas) {
    for (int i = 0; i < N; i++)        // fila por fila
      for (int j = 0; j < N; j++) suma += m[i * N + j];
  } else {
    for (int j = 0; j < N; j++)        // columna por columna
      for (int i = 0; i < N; i++) suma += m[i * N + j];
  }
  auto t1 = high_resolution_clock::now();

  printf("%s tiempo %ld ms checksum %.3f\n", por_filas ? "filas" : "columnas",
         duration_cast<milliseconds>(t1 - t0).count(), suma);
  return 0;
}
```

```bash
g++ -std=c++17 -O2 -g -o recorrido recorrido.cpp
./recorrido filas
./recorrido columnas
```

```
filas tiempo 13 ms checksum 20971516.250
columnas tiempo 1342 ms checksum 20971516.250
```

El mismo checksum, las mismas 16.777.216 sumas, y una versión tarda cien
veces lo que la otra. Los dos bucles son iguales salvo por cuál índice va
afuera. Los contadores de cada modo:

```bash
perf stat -e cycles,instructions,cache-references,cache-misses,L1-dcache-load-misses ./recorrido filas
perf stat -e cycles,instructions,cache-references,cache-misses,L1-dcache-load-misses ./recorrido columnas
```

```
filas tiempo 13 ms checksum 20971516.250
       136.586.179      cycles:u
       228.161.828      instructions:u
        10.622.190      cache-references:u
            86.731      cache-misses:u
         4.206.212      L1-dcache-load-misses:u

columnas tiempo 1558 ms checksum 20971516.250
     6.060.207.806      cycles:u
       228.161.966      instructions:u
       353.806.255      cache-references:u
       188.253.536      cache-misses:u
       195.167.086      L1-dcache-load-misses:u
```

Las instrucciones difieren en 138 sobre 228 millones; los ciclos son 44
veces más, y los fallos de L1, 46 veces más. Y lo que dice el simulador, con la
línea que el flujo de Actions lee:

```bash
valgrind --tool=cachegrind --cache-sim=yes --cachegrind-out-file=cg_filas.out ./recorrido filas 2>&1 | tee cg_filas.txt | tail -13
valgrind --tool=cachegrind --cache-sim=yes --cachegrind-out-file=cg_columnas.out ./recorrido columnas 2>&1 | tee cg_columnas.txt | tail -13
grep 'D1  miss rate' cg_filas.txt cg_columnas.txt
```

```
cg_filas.txt:==114059== D1  miss rate:        20.8% (      12.1%     +       32.7%  )
cg_columnas.txt:==114216== D1  miss rate:        69.2% (      96.0%     +       32.7%  )
```

`D refs` es 30.333.658 en los dos; las escrituras fallan igual (32,7 %,
son las del bucle que llena el arreglo) y las lecturas pasan de 12,1 % a
96,0 %. La cifra que se compara entre versiones es la primera de la línea,
la tasa combinada.

En `lento.cpp` hay tres arreglos y tres índices; la pregunta que deja
este ejemplo es cuál de los accesos del bucle interno avanza de a `N`
posiciones.

### Lo que suele fallar

- La aceleración se calcula con división entera: `t_lento / t_rapido` en
  bash tira los decimales, y 2,9 veces cuenta como 2. Hay que quedar por
  encima de 3,0 en la máquina de Actions, que es más lenta que un portátil;
  mejor apuntar a 4.
- `los dos programas no calculan lo mismo`: el checksum se compara como
  texto, hasta el último decimal. Los valores iniciales de `a` y `b`, el tipo
  `double` y el `%.3f` se quedan como están; lo único que se reescribe es el
  bucle.
- `el tiempo medido es cero`: la multiplicación no está, o quedó fuera del
  tramo entre `t0` y `t1`. Los dos `now()` abrazan solo el cálculo, ni la
  inicialización ni el checksum.
- Una línea de más en la salida (`printf` de depuración, un `cout` de
  prueba) desordena la lectura del flujo: `awk '{print $2}' rapido.txt`
  devuelve dos valores y la comparación falla con un mensaje confuso.
  `rapido` imprime una sola línea, con el formato exacto.
- Cambiar las banderas del Makefile para ganar velocidad: las dos versiones
  se compilan con las mismas, así que una bandera nueva acelera a `lento`
  igual y la aceleración no se mueve. La ganancia sale del orden de los
  accesos, no del compilador.
- Paralelizar con OpenMP en vez de cambiar el recorrido: el Makefile compila
  `rapido` sin `-fopenmp`, la verificación de Cachegrind pide que la versión
  rápida falle menos en D1, y repartir el mismo recorrido entre hilos no
  cambia la tasa de fallos.

### Enlaces

- [std::vector en cppreference](https://en.cppreference.com/w/cpp/container/vector):
  constructores, `operator[]` y la garantía de que los elementos son
  contiguos en memoria.
- [std::chrono::high_resolution_clock](https://en.cppreference.com/w/cpp/chrono/high_resolution_clock)
  y [duration_cast](https://en.cppreference.com/w/cpp/chrono/duration/duration_cast):
  cómo se toma un instante y cómo se convierte una diferencia a milisegundos.
- [printf en cppreference](https://en.cppreference.com/w/cpp/io/c/fprintf):
  los especificadores `%ld` y `%.3f`.
- [Orden por filas y por columnas](https://en.wikipedia.org/wiki/Row-_and_column-major_order):
  la fórmula `i * N + j`, su contraparte por columnas y qué lenguajes usan
  cada una.
- [Opciones de optimización de GCC](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html):
  qué hace `-O2` y qué desactiva `-fno-inline`.

## Paso 3: explicar

### Lo que se usa

- `ANALISIS.md` con sus cinco secciones ya tituladas. El nombre y el código
  van en la primera línea; cada paréntesis con instrucciones se reemplaza por
  el texto propio. El flujo cuenta palabras con `wc -w` y pide al menos 260;
  la plantilla vacía trae 172, así que el análisis aporta lo que falta y
  más.
- Las tablas en Markdown: una línea de encabezado, una de separadores
  (`|---|---:|` alinea esa columna a la derecha) y una fila por versión. Las
  celdas llevan el número con su unidad: `1.342 ms`, `69,2 %`.
- `grep 'D1  miss rate' evidencia/cachegrind_*.txt`, con dos espacios entre
  `D1` y `miss`, saca las dos tasas de los archivos que dejó
  `make cachegrind`. `grep 'D refs'` saca los accesos. Los tiempos y
  checksums están en `lento.txt` y `rapido.txt` después de `make comparar`.
- La aceleración es `tiempo lento / tiempo rápido`, con un decimal, medida
  con los binarios a secas y sin Valgrind por delante. `awk` la calcula sin
  redondear a entero.
- `git add evidencia/ ANALISIS.md` y el push: el flujo lee lo que está en el
  repositorio, no lo que está en el disco del portátil.

### Ejemplo

Con las salidas del programa de recorrido guardadas como deja `make comparar`
(`./recorrido columnas | tee columnas.txt`, `./recorrido filas | tee filas.txt`)
y los resúmenes de Cachegrind en `cg_filas.txt` y `cg_columnas.txt`:

```bash
awk 'FNR==1 && FILENAME=="columnas.txt" {tl=$3}
     FNR==1 && FILENAME=="filas.txt"    {tr=$3}
     END {printf "aceleracion %.1f (entera: %d)\n", tl/tr, int(tl/tr)}' columnas.txt filas.txt
grep 'D1  miss rate' cg_filas.txt cg_columnas.txt | awk '{print $1, $5}'
```

```
aceleracion 140.9 (entera: 140)
cg_filas.txt:==114059== 20.8%
cg_columnas.txt:==114216== 69.2%
```

Y un fragmento de cómo queda una sección de resultados escrita con esos
números, en `borrador.md`:

```markdown
## Resultado

| Versión | Tiempo | Checksum |
|---|---:|---|
| columnas | 1.832 ms | 20.971.516,250 |
| filas | 13 ms | 20.971.516,250 |

Aceleración obtenida: 140,9 veces. Las dos versiones ejecutan las mismas
228.161.828 instrucciones; la diferencia está en los 188.253.536 fallos
de caché del recorrido por columnas contra los 86.731 del recorrido por filas.
```

```bash
wc -w borrador.md
```

```
58 borrador.md
```

Cada afirmación del párrafo apunta a un número que está en un archivo de
`evidencia/`. Eso es lo que distingue una medición de una corazonada.

### Lo que suele fallar

- `ANALISIS.md tiene N palabras: falta el analisis`: el conteo incluye los
  títulos de la plantilla, y aun así no llega a 260. Dos o tres frases por
  sección no alcanzan; cada sección responde con los números que la
  respaldan.
- `Falta evidencia/perf.txt o esta vacio`: `make perfstat` no se corrió en la
  máquina propia, o se corrió y el archivo no se agregó al commit. El flujo
  no corre `perf` en el runner, así que ese archivo solo puede venir del
  portátil. Un `.gitignore` que excluya `*.txt` lo deja por fuera sin aviso;
  `git status` lo muestra.
- La tabla de fallos de caché se llena con los números de una sola corrida
  de `make cachegrind`, hecha antes de escribir `rapido.cpp`. Se repite la
  regla con la versión final y se copian las dos filas de esa corrida.
- Los tiempos de la tabla de resultados salen de `evidencia/callgrind.txt` o
  de la corrida de Cachegrind. Esos son tiempos bajo simulación; los reales
  son los de `lento.txt` y `rapido.txt`.
- La explicación de `ps` contra `top` dice que uno de los dos está mal. Los
  dos están bien y miden cosas distintas; la sección del Paso 0 dice qué
  calcula cada uno, y el análisis lo aplica a los cuatro hilos de
  `ocupado`.

### Enlaces

- [Tablas en GitHub](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/organizing-information-with-tables):
  la sintaxis que GitHub muestra, con la alineación por columna.
- [Registros de un run de Actions](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/monitoring-workflows/using-workflow-run-logs):
  dónde leer la salida de cada job y el resumen que el flujo deja.
- [Comandos de flujo de Actions](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions):
  qué son las anotaciones `::error file=...` que aparecen sobre el archivo
  cuando un paso falla.
- [gitignore](https://git-scm.com/docs/gitignore): cómo se resuelven los
  patrones y por qué un `*.txt` global esconde la evidencia.
- [Manual de gawk](https://www.gnu.org/software/gawk/manual/): `FNR`,
  `FILENAME` y `printf` para sacar números de archivos de texto.
- [wc(1)](https://man7.org/linux/man-pages/man1/wc.1.html): qué cuenta
  `-w` como palabra.

## Cómo compilar y ejecutar en la máquina propia

En Debian o Ubuntu:

```bash
sudo apt-get install build-essential valgrind htop time
sudo apt-get install linux-perf                      # Debian
sudo apt-get install linux-tools-common linux-tools-$(uname -r)   # Ubuntu
```

`g++` viene en `build-essential` y OpenMP está incluido en él; `-fopenmp` es
la única bandera adicional que `ocupado.cpp` necesita. Las banderas del
Makefile, `-std=c++17 -O2 -g`, se conservan: `-O2` es lo que hace que la
diferencia entre versiones sea de memoria y no de compilador, y `-g` es lo
que deja a Valgrind y a `perf` mostrar líneas de fuente. `/usr/bin/time`
viene en el paquete `time`; sin él, `time -v` responde con un error de la
shell.

Para `perf` como usuario normal:

```bash
cat /proc/sys/kernel/perf_event_paranoid        # 2 o menos sirve
sudo sysctl -w kernel.perf_event_paranoid=1
echo 'kernel.perf_event_paranoid = 1' | sudo tee /etc/sysctl.d/99-perf.conf
```

En Windows con WSL2 todo esto corre dentro de la distribución de Linux, con
dos diferencias. La primera: el kernel es el de Microsoft, así que
`linux-tools-$(uname -r)` no existe como paquete; se instala
`linux-tools-generic` y se invoca el binario por su ruta,
`/usr/lib/linux-tools/*/perf`. La segunda: la máquina virtual de WSL2 no
expone los contadores de hardware, y `perf stat` imprime `<not supported>`
en `cycles` y `cache-misses`. Valgrind, `ps`, `top` y `htop` funcionan
igual que en Linux nativo, así que Callgrind y Cachegrind cubren los pasos
1 y 2 completos; para `perf.txt` con contadores reales hace falta una
máquina con Linux instalado o una máquina virtual que los pase.

En macOS no hay `perf`, y Valgrind solo da soporte a macOS en Intel hasta
la versión 11 y no tiene versión para Apple Silicon. `ps -M` muestra hilos
con otras columnas y `top` tiene otras teclas, así que el Paso 0 sale distinto y los
Pasos 1 y 2 no salen. Lo que queda es una máquina virtual con Linux (UTM o
VirtualBox) o un contenedor de Docker con Debian, donde Valgrind corre; los
contadores de `perf` tampoco están disponibles dentro de la máquina virtual,
y `perf.txt` se toma en una máquina con Linux nativo.
