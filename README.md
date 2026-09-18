# Perfilado en Linux

Infraestructuras Paralelas y Distribuidas
Escuela de Ingeniería de Sistemas y Computación, Universidad del Valle
Carlos Andrés Delgado Saavedra

[![Pruebas](../../actions/workflows/pruebas.yml/badge.svg)](../../actions/workflows/pruebas.yml)

Lo que cada parte necesita de las bibliotecas y herramientas está en
[DOCUMENTACION.md](DOCUMENTACION.md), con ejemplos que corren y los enlaces
a la documentación oficial.

Un programa que funciona y es lento. La tarea no es adivinar por qué: es
medirlo con las herramientas del sistema, decidir con esos números qué cambiar,
y demostrar la mejora. Antes de eso, un paso corto para ver un programa de
varios hilos desde afuera, con las herramientas que muestran qué hace cada
hilo mientras corre.

## Requisitos

| Qué | Linux (Debian/Ubuntu) | macOS | Windows |
|---|---|---|---|
| `g++` con OpenMP y `make` | `sudo apt install build-essential` | máquina virtual con Linux | WSL2 con Ubuntu |
| Valgrind (Callgrind y Cachegrind) | `sudo apt install valgrind` | máquina virtual con Linux | dentro de WSL2, el mismo `apt` |
| `perf` | `sudo apt install linux-perf` en Debian; `sudo apt install linux-tools-generic` en Ubuntu | máquina virtual con Linux | dentro de WSL2, `linux-tools-generic` |
| `ps`, `top` y `htop` | `sudo apt install htop` (los otros dos vienen con el sistema) | máquina virtual con Linux | dentro de WSL2 |

Las herramientas de este ejercicio son de Linux. En macOS no hay Valgrind
ni `perf` para el procesador actual: se trabaja en una máquina virtual con
Debian o Ubuntu (UTM en Apple Silicon, VirtualBox en Intel). En WSL2 todo
corre dentro de la distribución; el paquete `linux-tools-generic` deja
`perf` en `/usr/lib/linux-tools/<versión>/perf`, y desde ahí se invoca.
Para que `perf stat` cuente eventos como usuario normal,
`kernel.perf_event_paranoid` tiene que estar en 2 o menos:

```bash
cat /proc/sys/kernel/perf_event_paranoid
sudo sysctl -w kernel.perf_event_paranoid=1
```

Cómo dejar cada sistema listo, paso a paso, está en
[DOCUMENTACION.md](DOCUMENTACION.md), al final.

## Paso 0: mirar un programa desde afuera

`ocupado.cpp` lanza cuatro hilos con OpenMP; el hilo `h` trabaja durante
`h + 1` segundos y termina. Mientras corre, `ps` y `top` lo muestran hilo por
hilo:

```bash
make monitor       # deja evidencia/ps.txt
```

La regla lanza el programa, espera dos segundos y medio y toma dos fotos:
`ps -L`, con un renglón por hilo y el `%CPU` promedio desde que el hilo
arrancó, y `top -H`, con el `%CPU` del último intervalo. Para el mismo hilo
los dos números no coinciden, y la explicación de por qué va en el análisis.
La columna `PSR` de `ps` dice en qué procesador estaba cada hilo en ese
instante.

Con `htop` se ve lo mismo en vivo: la tecla `H` muestra los hilos y `F2`
agrega la columna `PROCESSOR`. Con `./ocupado &` en una terminal y `htop`
en otra se ve a los hilos apagarse uno por uno.

## El programa

`lento.cpp` multiplica dos matrices de 512 por 512 e imprime el tiempo y un
checksum de la matriz resultante. El resultado es correcto; el problema es
cuánto tarda.

```bash
make lento && ./lento
```

## Paso 1: medir

Con Valgrind, para ver dónde se va el tiempo función por función:

```bash
make perfil        # deja evidencia/callgrind.txt
```

Con `perf`, para ver qué pasa con la caché:

```bash
make perfstat      # deja evidencia/perf.txt
```

Y con Cachegrind, que simula la caché y cuenta los fallos con exactitud:

```bash
make cachegrind    # deja evidencia/cachegrind_lento.txt y cachegrind_rapido.txt
```

Esta última regla corre sobre las dos versiones, así que su salida completa
solo se tiene al terminar el paso 2. La línea que importa es `D1 miss rate`:
qué fracción de los accesos a datos no encontró lo que buscaba en la caché
de primer nivel.

Las salidas se guardan en `evidencia/` y se suben al repositorio. Son la
prueba de que la decisión salió de una medición y no de una corazonada.

Si trabaja en Windows, las dos herramientas corren dentro de WSL2. En macOS no
están disponibles: use una máquina virtual con Linux.

## Paso 2: escribir la versión rápida

En `rapido.cpp` está el mismo programa con la multiplicación por escribir. Debe
imprimir el mismo checksum, con el mismo formato de salida, y correr al menos
tres veces más rápido.

Una pista, y solo una: la matriz está guardada por filas.

```bash
make comparar
```

## Paso 3: explicar

`ANALISIS.md` con lo que mostraron `ps` y `top`, lo que mostró el perfil, los
fallos de caché de las dos versiones, qué se cambió y cuánto se ganó. El
número de la aceleración va en la tabla.

## Qué revisa el flujo de Actions

- Paso 0: que `ps` vea los cuatro hilos.
- Pasos 1 y 2: que las dos versiones compilen, que los checksums coincidan,
  que la aceleración llegue a tres veces, que la versión rápida falle menos
  en D1 que la lenta y que Callgrind corra sobre ella.
- Evidencia: que `evidencia/` tenga las salidas y que `ANALISIS.md` tenga el
  análisis.

Cada paso es un job aparte: la lista de verificaciones del commit dice cuál
quedó en verde y cuál no, y la pestaña del run trae un resumen con las
salidas. Cuando la verificación de tiempos falla, el flujo repite la corrida
una vez antes de marcar rojo, y el error queda anotado sobre el archivo de
ese paso. Un push nuevo cancela el run anterior.

## Para pensar

La aceleración que se obtiene aquí no viene de usar más núcleos: el programa
sigue siendo de un solo hilo. Viene de pedirle a la memoria lo que ya tenía
cerca. Las dos versiones hacen la misma cantidad de multiplicaciones y Cachegrind
cuenta casi los mismos accesos a datos; lo que cambia es cuántos de esos
accesos encuentran la línea ya cargada. Vale la pena repetir `perf stat` sobre
la versión rápida y ver si el contador de hardware cuenta lo mismo que el
simulador.
