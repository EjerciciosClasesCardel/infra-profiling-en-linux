# Perfilado en Linux

Infraestructuras Paralelas y Distribuidas
Escuela de Ingeniería de Sistemas y Computación, Universidad del Valle
Carlos Andrés Delgado Saavedra

Un programa que funciona y es lento. La tarea no es adivinar por qué: es
medirlo con las herramientas del sistema, decidir con esos números qué cambiar,
y demostrar la mejora.

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

Las dos salidas se guardan en `evidencia/` y se suben al repositorio. Son la
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

`analisis.md` con qué mostró el perfil, qué se cambió y cuánto se ganó. El
número de la aceleración va en la tabla.

## Qué revisa el flujo de Actions

Que las dos versiones compilen, que los checksums coincidan, que la aceleración
llegue a tres veces, que Callgrind corra sobre la versión rápida, y que la
evidencia y el análisis estén en el repositorio.

## Para pensar

La aceleración que se obtiene aquí no viene de usar más núcleos: el programa
sigue siendo de un solo hilo. Viene de pedirle a la memoria lo que ya tenía
cerca. Vale la pena repetir la medición de `perf stat` sobre la versión rápida
y comparar los fallos de caché con los de la primera.
